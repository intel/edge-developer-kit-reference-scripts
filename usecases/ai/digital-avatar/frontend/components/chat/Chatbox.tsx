// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { Send, Mic, Ban, EllipsisVertical } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useChat } from '@ai-sdk/react'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import useAudioRecorder from '@/hooks/useAudioRecorder'
import { useGetLipsync } from '@/hooks/useLipsync'
import { useGetTTSAudio } from '@/hooks/useTTS'
import useVideoQueue from '@/hooks/useVideoQueue'

import Loading from './loading'
import Markdown from './Markdown'
import { Popover, PopoverContent, PopoverTrigger } from '../ui/popover'
import Spinner from '../ui/spinner'
import { PerformanceResults } from '@/types/performanceResults'
import { useGetConfig } from '@/hooks/useConfig'
import { SelectedPipelineConfig } from '@/types/config'
import { useCreatePerformanceResult } from '@/hooks/usePerformanceResult'

interface StreamData {
    index: number,
    message: string,
    processed: boolean
}

export default function Chatbox() {
    const { data: configResponse } = useGetConfig()
    const { mutateAsync: createPerformanceResult } = useCreatePerformanceResult()
    const { messages, input, setInput, append, handleSubmit, data, status, stop, setMessages } = useChat({
        onFinish: (message) => {
            // Save LLM performance results
            try {
                const messageAnnotation = message.annotations?.[0] as {
                    ttft: number
                    totalNextTokenLatency: number
                    usage: {
                        completionTokens: number
                        promptTokens: number
                        totalTokens: number
                    }
                }
                if (messageAnnotation) {
                    setPerformanceResults(prev => ({
                        ...prev,
                        llm: {
                            ttft: messageAnnotation.ttft,
                            totalLatency: messageAnnotation.totalNextTokenLatency,
                            throughput: messageAnnotation.usage.completionTokens / messageAnnotation.totalNextTokenLatency,
                        },
                        metadata: {
                            ...prev.metadata,
                            ...messageAnnotation.usage
                        }
                    }));
                }
            } catch (error) {
                console.error("Error in onFinish:", error)
            }
        }
    })
    const { startRecording, stopRecording, recording, durationSeconds, visualizerData, sttMutation, isDeviceFound } = useAudioRecorder()
    const { addVideo, updateVideo, currentFrame, fps, isReversed, framesLength, getTotalVideoDuration, isQueueEmpty, reset } = useVideoQueue()
    const chatBottomRef = useRef<HTMLDivElement>(null)
    const getTTSAudio = useGetTTSAudio()
    const getLipsync = useGetLipsync()
    const [taskQueue, setTaskQueue] = useState<Record<string, string | number>[]>([])
    const [isProcessing, setIsProcessing] = useState(false)
    const [isCalling, setIsCalling] = useState(false)
    const [performanceResults, setPerformanceResults] = useState<PerformanceResults>({})
    const latency = 1500 // assuming there is a delay of 500ms to transfer and receive files for each second
    const minGenerationTime = 200  // assuming it takes 0.05s everytime there is a lipsync request
    const lipsyncGenerationTimePerSecond = 300 // assuming it takes 0.4s to generate lipsync for 1s audio

    const formatSeconds = (seconds: number) => {
        const minutes = Math.floor(seconds / 60)
        const remainingSeconds = seconds % 60
        const formattedSeconds = remainingSeconds < 10 ? `0${remainingSeconds}` : remainingSeconds
        return `${minutes}:${formattedSeconds}`
    }

    const savePerformanceResults = async (performanceResults: PerformanceResults, selectedConfig: SelectedPipelineConfig) => {
        try {
            await createPerformanceResult({
                denoise: performanceResults.denoise,
                stt: performanceResults.stt,
                llm: performanceResults.llm,
                tts: performanceResults.tts?.map(result => ({
                    httpLatency: result.httpLatency ?? 0,
                    inferenceLatency: result.inferenceLatency ?? 0,
                    metadata: result.metadata ?? null,
                })),
                lipsync: performanceResults.lipsync?.map(result => ({
                    httpLatency: result.httpLatency ?? 0,
                    inferenceLatency: result.inferenceLatency ?? 0,
                    metadata: result.metadata ?? null,
                })),
                metadata: performanceResults.metadata ? { ...performanceResults.metadata } : undefined,
                config: {...selectedConfig},
            })
        } catch (error) {
            console.error("Error saving performance results:", error)
        }
    }

    const handleStopChat = () => {
        stop()
        cleanup()
    }

    const handleStartRecording = () => {
        cleanup()
        startRecording()
        setIsCalling(true)
    }

    const handleStopRecording = (save: boolean = false) => {
        stopRecording(save)
        setIsCalling(false)
    }

    const handleClearChat = () => {
        cleanup()
        handleStopChat()
        setMessages([])
    }

    const cleanup = () => {
        // Cleanup task queue
        setTaskQueue([]);

        // Reset performance results
        setPerformanceResults({});

        // Reset video queue
        reset();
    }

    useEffect(() => {
        return () => {
            cleanup();
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Ensure scroll to bottom when new message is added
    useEffect(() => {
        if (chatBottomRef.current) {
            chatBottomRef.current.scrollIntoView()
        }
    }, [messages])
    
    // Add each trun sentence to task queue
    useEffect(() => {
        if (data) {
            const streamData: (StreamData | null)[] = data as (StreamData | null)[]
            streamData.forEach((d) => {
                if (d && !d.processed) {
                    d.processed = true
                    setTaskQueue(prev => { return [...prev, { id: d.index, text: d.message }] })
                }
            })
        }
    }, [data])

    useEffect(() => {
        if (isCalling && status !== "streaming" && isQueueEmpty && !recording && !sttMutation.isSuccess && !sttMutation.isPending) {
            console.log('start')
            startRecording()
        }
        
        if (performanceResults.lipsync) {
            if (configResponse?.data) {
                const selectedConfig: SelectedPipelineConfig =  {
                    denoiseStt: configResponse.data.denoiseStt.selected_config,
                    llm: configResponse.data.llm.selected_config,
                    tts: configResponse.data.tts.selected_config,
                    lipsync: configResponse.data.lipsync.selected_config,
                }

                // Save performance results + config to database
                savePerformanceResults(performanceResults, selectedConfig).catch((error) => {
                    console.error("Error saving performance results:", error)
                })
            }
            
            setPerformanceResults({})
        }
    }, [isQueueEmpty, status, isCalling, recording, sttMutation.isSuccess, sttMutation.isPending, startRecording])

    // Process task queue items one by one
    useEffect(() => {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const calculateVideoStart = (duration: number) => {
            const totalTime = (lipsyncGenerationTimePerSecond * duration) + latency + minGenerationTime
            let frameAdjustment = (totalTime / 1000) * fps
            // console.log(`Estimated Time: ${totalTime}`)
            let reversed = isReversed
            // let reverseCount = 0
            while (frameAdjustment > framesLength) {
                reversed = !reversed
                frameAdjustment -= framesLength
                // reverseCount += 1
            }

            let index
            if (reversed) {
                index = currentFrame - frameAdjustment
                if (index < 0) {
                    reversed = !reversed
                    index = -index
                }
            } else {
                index = currentFrame + frameAdjustment
                if (index > framesLength) {
                    reversed = !reversed
                    index = framesLength - (index - framesLength)
                }
            }
            index = Math.ceil(index)
            if (index === framesLength) {
                index -= 1
            }
            // console.log(currentFrame, isReversed, index, frameAdjustment, frameAdjustment + framesLength * reverseCount)
            return { startIndex: index, reversed }
        }

        const processText = async (index: number, text: string) => {
            const processedText = text.replace(/[*#]|[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/gu, "").trim();
            if (processedText.length >= 0) {
                addVideo({ id: index, url: undefined })

                // TTS
                const { data: ttsData } = await getTTSAudio.mutateAsync({ text: processedText })

                // const { startIndex, reversed } = calculateVideoStart(ttsData.duration + getTotalVideoDuration())
                const startIndex = 0
                const reversed = false

                // Lipsync
                const { data: lipsyncData } = await getLipsync.mutateAsync({ data: { filename: ttsData.filename }, startIndex: startIndex.toString(), reversed: reversed ? "1" : "0" })
                updateVideo(index, lipsyncData.url, startIndex, reversed, ttsData.duration)

                setPerformanceResults(prev => {
                    const newResults = {
                        ...prev,
                        tts: [
                            ...(prev.tts || []), // Append to the existing array or initialize if undefined
                            {
                                httpLatency: ttsData.http_latency,
                                inferenceLatency: ttsData.inference_latency,
                                metadata: { outputAudioDuration: ttsData.duration }
                            }
                        ],
                        lipsync: [
                            ...(prev.lipsync || []), // Append to the existing array or initialize if undefined
                            {
                                httpLatency: lipsyncData.http_latency,
                                inferenceLatency: lipsyncData.inference_latency,
                                metadata: { framesGenerated: lipsyncData.frames_generated }
                            }
                        ],
                    };

                    // Only update if the new results are different
                    if (JSON.stringify(prev) !== JSON.stringify(newResults)) {
                        return newResults;
                    }
                    return prev;
                });
            }

            setIsProcessing(false)
            setTaskQueue(prev => { return prev.slice(1) })
        }

        if (taskQueue.length > 0 && !isProcessing) {
            const task = taskQueue[0]
            setIsProcessing(true)
            processText(task.id as number, task.text as string)
        }
    }, [taskQueue, isProcessing, addVideo, getTTSAudio, getLipsync, updateVideo, currentFrame, fps, isReversed, framesLength, getTotalVideoDuration])

    useEffect(() => {
        if (sttMutation.data && sttMutation.data.status && sttMutation.data.metrics) {
            try {
                // Save STT performance results
                const { 
                    denoise_latency: denoiseInferenceLatency, 
                    stt_latency: sttInferenceLatency,
                    http_latency: httpLatency,
                } = sttMutation.data.metrics

                setPerformanceResults(prev => {
                    const newResults = {
                        ...prev,
                        denoise: {
                            inferenceLatency: denoiseInferenceLatency,
                        },
                        stt: {
                            inferenceLatency: sttInferenceLatency,
                            httpLatency: httpLatency,
                        },
                        metadata: {
                            ...prev.metadata,
                            inputAudioDurationInSeconds: durationSeconds
                        }
                    };

                    // Only update if the new results are different
                    if (JSON.stringify(prev) !== JSON.stringify(newResults)) {
                        return newResults;
                    }
                    return prev;
                });

                // Add STT result to chat
                append({ content: sttMutation.data.text, role: "user" }).then(() => {
                    sttMutation.reset()
                    stopRecording()
                })
            } catch (error) {
                console.error("Error processing STT data:", error)
            }
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- sttMutatio.reset added todependency will cause infinite loop
    }, [sttMutation.status, sttMutation.data])

    useEffect(() => {
        if (isCalling || recording) {
            handleStopRecording()
        }
    }, [isDeviceFound])

    return (
        <>
            <ScrollArea className="h-72 grow p-4" >
                {messages.map((message, index) => (
                    <div key={index} className={`mb-4 ${message.role !== "user" ? 'text-left' : 'text-right'}`}>
                        <div className={`inline-block p-2 rounded-lg ${message.role !== "user" ? 'bg-muted text-muted-foreground' : 'bg-primary text-primary-foreground'}`}>
                            <Markdown content={message.content} />
                        </div>
                    </div>
                ))}
                {
                    sttMutation.isPending && <div className={`mb-4 text-right`}>
                        <div className={`inline-block p-2 rounded-lg bg-primary text-primary-foreground`}>
                            <Loading />
                        </div>
                    </div>
                }
                <div ref={chatBottomRef} />
            </ScrollArea>
            <div className="flex space-x-1 mb-1">
                {

                    isCalling && (status === "streaming" || !isQueueEmpty || sttMutation.isPending) ?
                        <div className="flex flex-1 self-center items-center justify-center overflow-hidden h-6" dir="rtl">
                            <Spinner size={24} />
                        </div>
                        : (
                            <div className="flex flex-1 self-center items-center justify-between overflow-hidden h-6" dir="rtl">
                                <span className="ml-2 text-sm text-gray-500">{formatSeconds(durationSeconds)}</span>
                                <div className="flex items-center gap-0.5 h-6 w-full max-w-full overflow-hidden flex-wrap">
                                    {visualizerData.slice().reverse().map((rms, index) => (
                                        <div key={index} className="flex items-center h-full">
                                            <div
                                                className={`w-[2px] shrink-0 ${recording ? 'bg-indigo-500 dark:bg-indigo-400' : 'bg-gray-500 dark:bg-gray-400'} inline-block h-full`}
                                                style={{ height: `${Math.min(100, Math.max(14, rms * 100))}%` }}
                                            />
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}
                {
                    !isCalling && !recording &&
                    <>
                        <Input
                            type="text"
                            placeholder="Type your message..."
                            value={input}
                            onChange={(e) => setInput(e.target.value)}
                            onKeyDown={async (ev) => {
                                if (ev.key === "Enter") {
                                    cleanup()
                                    append({ content: input, role: "user" })
                                    setInput("")
                                }
                            }}
                            disabled={status === "streaming"}
                            className="grow"
                        />
                        {
                            (status === "streaming" || !isQueueEmpty) ?
                                <Button onClick={handleStopChat} variant="destructive" size="icon">
                                    <Ban color="white" className="size-4" />
                                    <span className="sr-only">Stop Chat</span>
                                </Button>
                                :
                                (input.trim() || status === "submitted") && 
                                    <Button onClick={() => {
                                        cleanup()
                                        handleSubmit()
                                    }} disabled={status === "submitted"} size="icon">
                                        <Send className="size-3" />
                                        <span className="sr-only">Send</span>
                                    </Button>
                        }

                    </>
                }
                {
                    isCalling ? (
                        <Button size="icon" variant="destructive" onClick={() => {
                            handleStopChat()
                            handleStopRecording()
                        }} color="red">
                            <Ban color="white" className="size-4" />
                            <span className="sr-only">Stop recording</span>
                        </Button>
                    ) : (!input.trim() && !(status === "streaming" || status === "submitted" || !isQueueEmpty || sttMutation.isPending) &&
                        <Button size="icon" onClick={handleStartRecording} disabled={!isDeviceFound}>
                            <Mic className="size-4" />
                            <span className="sr-only">Voice input</span>
                        </Button>
                    )
                }
                <Popover>
                    <PopoverTrigger asChild>
                        <Button size="icon" variant="outline" className='w-6 mr-1'>
                            <EllipsisVertical />
                        </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-30">
                        <div className="flex">
                            <Button onClick={handleClearChat}>Clear Chat</Button>
                        </div>
                    </PopoverContent>
                </Popover>
            </div>
        </>
    )
}