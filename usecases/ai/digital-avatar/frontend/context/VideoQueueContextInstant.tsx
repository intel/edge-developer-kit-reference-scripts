// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import React, { createContext, useState, ReactNode, useMemo, useCallback, useRef, useEffect } from 'react';

interface Video {
    id: number;
    url?: string | undefined;
    el?: HTMLVideoElement | undefined;
    reversed?: boolean | undefined;
    duration?: number | undefined;
}

export interface VideoQueueContextProps {
    queue: Video[];
    addVideo: (video: Video) => void;
    popVideo: () => void;
    currentVideo: Video | undefined;
    updateVideo: (id: number, url: string, startIndex: number, reversed: boolean, duration: number) => void;
    updateRefs: (video: HTMLVideoElement, canvas: HTMLCanvasElement) => void;
    handleVideoLoaded: () => void;
    getTotalVideoDuration: () => number;
    isQueueEmpty: boolean;
    isLoading: boolean;
    currentFrame: number;
    fps: number;
    isReversed: boolean;
    framesLength: number;
    reset: VoidFunction
}

export const VideoQueueContext = createContext<VideoQueueContextProps>({} as VideoQueueContextProps);
export const VideoQueueProvider = ({ children }: { children: ReactNode }) => {
    const [queue, setQueue] = useState<Video[]>([]);
    const currentFrame = 0
    // const [timeoutId, setTimeoutId] = useState<NodeJS.Timeout | null>(null);
    const [videoData, setVideoData] = useState<Record<string, string | number | HTMLVideoElement>>({ status: "idle" });
    // const [isReversed, setIsReversed] = useState(false)
    const [isLoading, setIsLoading] = useState(true)
    const [frames, setFrames] = useState<ImageData[]>([]);

    const FPS = 25

    const videoRef = useRef<HTMLVideoElement | null>(null);
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const timeoutIDRef = useRef<NodeJS.Timeout | null>(null);
    const isReversedRef = useRef<boolean>(false)

    const isQueueEmpty = useMemo(() => {
        return queue.length === 0
    }, [queue])

    const addVideo = (video: Video) => {
        setQueue((prevQueue) => [...prevQueue, video]);
    };

    const updateVideo = (id: number, url: string, startIndex: number, reversed: boolean, duration: number) => {
        setQueue((prevQueue) => {
            const video = document.createElement('video');
            video.src = `/api/lipsync/v1/video/${url}`;
            return prevQueue.map((item) => {
                if (item.id === id) {
                    return { ...item, url, duration, el: video }
                }
                return { ...item }
            })
        });
    };

    const popVideo = useCallback(() => {
        setQueue((prevQueue) => { return prevQueue.slice(1) });
    }, []);

    const updateRefs = useCallback((video: HTMLVideoElement, canvas: HTMLCanvasElement) => {
        videoRef.current = video;
        canvasRef.current = canvas;
    }, [])

    const currentVideo = useMemo(() => {
        return queue[0];
    }, [queue])

    const getTotalVideoDuration = useCallback(() => {
        let duration = 0
        queue.forEach(video => {
            if (video.duration)
                duration += video.duration
        })

        return duration
    }, [queue])

    const handleVideoLoaded = async () => {
        const video = videoRef.current;
        const canvas = canvasRef.current;
        if (!canvas || !video)
            return;
        const aspectRatio = video.videoWidth / video.videoHeight;
        canvas.width = video.videoWidth;
        canvas.height = canvas.width / aspectRatio;

        const tempCanvas = document.createElement("canvas")
        tempCanvas.width = video.videoWidth;
        tempCanvas.height = tempCanvas.width / aspectRatio;
        const context = tempCanvas.getContext('2d', { willReadFrequently: true });
        if (!context)
            return;

        const frameArray: ImageData[] = [];
        const captureFrame = () => {
            context.drawImage(video, 0, 0, canvas.width, canvas.height);
            const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
            if (imageData.data.some(value => value !== 0)) {
                frameArray.push(imageData);
            }
        };
        video.addEventListener("play", () => {
            const interval = setInterval(() => {
                if (video.paused || video.ended) {
                    clearInterval(interval);
                    setIsLoading(false)
                    setFrames(frameArray)
                } else {
                    captureFrame();
                }
            }, 1000 / FPS);
        })

        video.play()
    }

    const playVideoURL = useCallback((video: HTMLVideoElement) => {
        const canvas = canvasRef.current;
        if (!canvas) return;
        const context = canvas.getContext('2d');
        if (!context) return;

        video.addEventListener('play', () => {
            const drawFrame = () => {
                if (video.paused || video.ended) {
                    popVideo();
                    setVideoData({ status: "none" })
                    return
                };
                context.drawImage(video, 0, 0, canvas.width, canvas.height);
                requestAnimationFrame(drawFrame);
            };
            drawFrame();
        });

        video.play()
    }, [popVideo])

    const playIdleVideo = useCallback(() => {
        const canvas = canvasRef.current;
        if (!canvas || frames.length === 0) return;
        const context = canvas.getContext('2d');
        if (!context) return;
        const isReversed = isReversedRef.current
        let currentFrameIndex = isReversed ? frames.length - 1 : 0;
        currentFrameIndex = currentFrameIndex === frames.length ? currentFrameIndex - 1 : currentFrameIndex
        const direction = isReversed ? -1 : 1;
        const frameDelay = 1000 / FPS;
        const playFrames = () => {
            context.putImageData(frames[currentFrameIndex], 0, 0);
            currentFrameIndex += direction;
            // setCurrentFrame(currentFrameIndex)
            if (currentFrameIndex === frames.length - 1 || currentFrameIndex === 0) {
                // setIsReversed(prev => !prev)
                isReversedRef.current = !isReversed
                setVideoData({ status: "none" })
                return
            }
            const timeoutId = setTimeout(playFrames, frameDelay);
            timeoutIDRef.current = timeoutId
        };

        playFrames();
    }, [frames])

    const reset = useCallback(() => {
        setQueue([])
        if (videoData.el) {
            (videoData.el as HTMLVideoElement).pause()
        }
        // setVideoData({ status: "idle" })
    }, [videoData])


    useEffect(() => {
        if (!frames || frames.length < 1)
            return

        if ((!currentVideo || !currentVideo.url) && videoData.status === "none") {
            setVideoData({ status: "idle" })
        } else if (currentVideo && currentVideo.url && currentVideo.el) {
            if (videoData.status !== "play") {
                if (timeoutIDRef.current)
                    clearTimeout(timeoutIDRef.current as NodeJS.Timeout)
                setVideoData({ status: "play", url: currentVideo.url, el: currentVideo.el })
            }
        }
    }, [frames, currentVideo, videoData])

    useEffect(() => {
        if (videoData.status === "idle") {
            playIdleVideo()
        }
        else if (videoData.status === "play" && videoData.el) {
            playVideoURL(videoData.el as HTMLVideoElement)
        }
    }, [videoData, playIdleVideo, playVideoURL])

    return (
        <VideoQueueContext.Provider value={{ isQueueEmpty, reset, queue, addVideo, popVideo, currentVideo, updateVideo, updateRefs, handleVideoLoaded, isLoading, currentFrame, fps: FPS, isReversed: isReversedRef.current, framesLength: frames.length, getTotalVideoDuration }}>
            {children}
        </VideoQueueContext.Provider>
    );
};