import { useChat } from 'ai/react'
import { Send, Mic, StopCircle } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import useAudioRecorder from '@/hooks/useAudioRecorder'
import { useGetLipsync } from '@/hooks/useLipsync'
import { useGetTTSAudio } from '@/hooks/useTTS'
import useVideoQueue from '@/hooks/useVideoQueue'

import Markdown from './Markdown'


interface StreamData {
    index: number,
    message: string,
    processed: boolean
}

export default function Chat() {
    const { messages, input, setInput, append, handleSubmit, data, isLoading } = useChat();
    const { startRecording, stopRecording, recording, durationSeconds, visualizerData, sttMutation } = useAudioRecorder();
    const { addVideo, updateVideo } = useVideoQueue()
    const chatBottomRef = useRef<HTMLDivElement>(null)
    const getTTSAudio = useGetTTSAudio()
    const getLipsync = useGetLipsync()
    const [taskQueue, setTaskQueue] = useState<Record<string, string | number>[]>([])
    const [isProcessing, setIsProcessing] = useState(false)

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

    // Process task queue items one by one
    useEffect(() => {
        const processText = async (index: number, text: string) => {
            addVideo({ id: index, url: undefined })

            console.time(`process for message ${index}`)
            // TTS
            const speech = await getTTSAudio.mutateAsync({ text })

            const file = new File([speech], "speech.wav", { type: "audio/wav" })

            // Lipsync
            const form = new FormData()
            form.append("file", file)
            const response = await getLipsync.mutateAsync({ data: form })
            const url = URL.createObjectURL(response)
            updateVideo(index, url)
            console.timeEnd(`process for message ${index}`)

            setIsProcessing(false)
            setTaskQueue(prev => { return prev.slice(1) })
        }

        if (taskQueue.length > 0 && !isProcessing) {
            const task = taskQueue[0]
            setIsProcessing(true)
            processText(task.id as number, task.text as string)
        }


    }, [taskQueue, isProcessing, addVideo, getTTSAudio, getLipsync, updateVideo])

    const formatSeconds = (seconds: number) => {
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = seconds % 60;
        const formattedSeconds = remainingSeconds < 10 ? `0${remainingSeconds}` : remainingSeconds;
        return `${minutes}:${formattedSeconds}`;
    };

    useEffect(() => {
        if (sttMutation.status === "success" && sttMutation.data) {
            append({ content: sttMutation.data.text, role: "user" })
            sttMutation.reset()
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- sttMutation.reset added to dependency will cause infinite loop
    }, [append, sttMutation.status, sttMutation.data])

    return (
        <>
            <div className="p-4 flex justify-between items-center border-b">
                <h2 className="text-xl font-semibold">Chat</h2>
            </div>
            <ScrollArea className="h-72 grow p-4" >
                {messages.map((message, index) => (
                    <div key={index} className={`mb-4 ${message.role !== "user" ? 'text-left' : 'text-right'}`}>
                        <div className={`inline-block p-2 rounded-lg ${message.role !== "user" ? 'bg-muted text-muted-foreground' : 'bg-primary text-primary-foreground'}`}>
                            <Markdown content={message.content} />
                        </div>
                    </div>
                ))}
                <div ref={chatBottomRef} />
            </ScrollArea>
            <div className="flex space-x-2">
                {recording ? (
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
                ) : (
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
                        <Button onClick={handleSubmit} size="icon" disabled={isLoading}>
                            <Send className="size-4" />
                            <span className="sr-only">Send</span>
                        </Button>
                    </>
                )}

                {recording ? (
                    <Button size="icon" variant="outline" onClick={stopRecording}>
                        <StopCircle fill="red" className="size-4 text-red-500" />
                        <span className="sr-only">Stop recording</span>
                    </Button>
                ) : (
                    <Button size="icon" variant="outline" onClick={startRecording}>
                        <Mic className="size-4" />
                        <span className="sr-only">Voice input</span>
                    </Button>
                )}
            </div>
        </>
    )
}