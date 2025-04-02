// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { useChat } from 'ai/react'
import { Send, Mic, Ban, EllipsisVertical } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import useAudioRecorder from '@/hooks/useAudioRecorder'
import { useGetLipsync } from '@/hooks/useLipsync'
import { useGetTTSAudio } from '@/hooks/useTTS'
import useVideoQueue from '@/hooks/useVideoQueue'

import Loading from './loading'
import Markdown from './Markdown'
import { ISettings } from './settings/SettingsDialog'
import { Popover, PopoverContent, PopoverTrigger } from '../ui/popover'
import Spinner from '../ui/spinner'

interface StreamData {
    index: number,
    message: string,
    processed: boolean
}

export default function Chatbox({ settings }: { settings: ISettings }) {
    const { messages, input, setInput, append, handleSubmit, data, isLoading, stop, setMessages } = useChat({
        body: { model: settings.model }
    });
    const { startRecording, stopRecording, recording, durationSeconds, visualizerData, sttMutation } = useAudioRecorder();
    const { addVideo, updateVideo, currentFrame, fps, isReversed, framesLength, getTotalVideoDuration, isQueueEmpty, reset } = useVideoQueue()
    const chatBottomRef = useRef<HTMLDivElement>(null)
    const getTTSAudio = useGetTTSAudio()
    const getLipsync = useGetLipsync()
    const [taskQueue, setTaskQueue] = useState<Record<string, string | number>[]>([])
    const [isProcessing, setIsProcessing] = useState(false)
    const [isCalling, setIsCalling] = useState(false)
    const latency = 1500 // assuming there is a delay of 500ms to transfer and receive files for each second
    const minGenerationTime = 200  // assuming it takes 0.05s everytime there is a lipsync request
    const lipsyncGenerationTimePerSecond = 300; // assuming it takes 0.4s to generate lipsync for 1s audio
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
        if (isCalling && !isLoading && isQueueEmpty && !recording && !sttMutation.isSuccess && !sttMutation.isPending) {
            console.log('start')
            startRecording()
        }
    }, [isQueueEmpty, isLoading, isCalling, recording, sttMutation.isSuccess, sttMutation.isPending, startRecording])

    // Process task queue items one by one
    useEffect(() => {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const calculateVideoStart = (duration: number) => {
            const totalTime = (lipsyncGenerationTimePerSecond * duration) + latency + minGenerationTime;
            let frameAdjustment = (totalTime / 1000) * fps;
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
            return { startIndex: index, reversed };
        };

        const processText = async (index: number, text: string) => {
            addVideo({ id: index, url: undefined })

            // console.time(`Total time for message ${index}`)
            // TTS
            const { data: ttsData } = await getTTSAudio.mutateAsync({ text, speaker: settings.gender })

            // const { startIndex, reversed } = calculateVideoStart(ttsData.duration + getTotalVideoDuration())
            const startIndex = 0
            const reversed = false

            // Lipsync
            const { data: lipsyncData } = await getLipsync.mutateAsync({ data: { filename: ttsData.filename, expressionScale: settings.expressionScale }, startIndex: startIndex.toString(), reversed: reversed ? "1" : "0" })
            updateVideo(index, lipsyncData.url, startIndex, reversed, ttsData.duration)
            // console.timeEnd(`Total time for message ${index}`)

            setIsProcessing(false)
            setTaskQueue(prev => { return prev.slice(1) })
        }

        if (taskQueue.length > 0 && !isProcessing) {
            const task = taskQueue[0]
            setIsProcessing(true)
            processText(task.id as number, task.text as string)
        }
    }, [taskQueue, isProcessing, addVideo, getTTSAudio, getLipsync, updateVideo, currentFrame, fps, isReversed, framesLength, getTotalVideoDuration, settings.gender, settings.expressionScale])

    const formatSeconds = (seconds: number) => {
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = seconds % 60;
        const formattedSeconds = remainingSeconds < 10 ? `0${remainingSeconds}` : remainingSeconds;
        return `${minutes}:${formattedSeconds}`;
    };

    useEffect(() => {
        if (sttMutation.status === "success" && sttMutation.data) {
            append({ content: sttMutation.data.text, role: "user" }).then(() => {
                sttMutation.reset()
                stopRecording()
            })
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- sttMutation.reset added to dependency will cause infinite loop
    }, [append, sttMutation.status, sttMutation.data, isCalling, startRecording])

    const handleStopChat = () => {
        stop()
        reset()
        setTaskQueue([])
    }

    const handleStartRecording = () => {
        startRecording()
        setIsCalling(true)
    }

    const handleStopRecording = () => {
        stopRecording(false)
        setIsCalling(false)
        handleStopChat()
    }

    const handleClearChat = () => {
        handleStopChat()
        setMessages([])
    }

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
            <div className="flex space-x-2">
                {

                    isCalling && (isLoading || !isQueueEmpty || sttMutation.isPending) ?
                        <div className="flex flex-1 self-center items-center justify-center ml-2 mx-1 overflow-hidden h-6" dir="rtl">
                            <Spinner size={24} />
                        </div>
                        : (
                            <div className="flex flex-1 self-center items-center justify-between ml-2 mx-1 overflow-hidden h-6" dir="rtl">
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
                                    append({ content: input, role: "user" })
                                    setInput("")
                                }
                            }}
                            disabled={isLoading}
                            className="grow"
                        />
                        {
                            isLoading || !isQueueEmpty ?
                                <Button onClick={handleStopChat} variant="destructive" size="icon">
                                    <Ban color="white" />
                                    <span className="sr-only">Stop Chat</span>
                                </Button>

                                :
                                <Button onClick={handleSubmit} size="icon" disabled={isLoading}>
                                    <Send className="size-4" />
                                    <span className="sr-only">Send</span>
                                </Button>
                        }

                    </>
                }
                {
                    isCalling ? (
                        <Button size="icon" variant="destructive" onClick={handleStopRecording} color="red">
                            <Ban color="white" />
                            <span className="sr-only">Stop recording</span>
                        </Button>
                    ) : (
                        <Button size="icon" disabled={isLoading || !isQueueEmpty || sttMutation.isPending} onClick={handleStartRecording}>
                            <Mic className="size-4" />
                            <span className="sr-only">Voice input</span>
                        </Button>
                    )}
                <Popover>
                    <PopoverTrigger asChild>
                        <Button size="icon" variant="outline" className='w-6'>
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