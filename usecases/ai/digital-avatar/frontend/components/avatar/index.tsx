// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { useEffect, useRef, useState } from 'react';

import useVideoQueue from '@/hooks/useVideoQueue';

export default function Avatar() {
    const { currentVideo, popVideo } = useVideoQueue();
    const videoRef = useRef<HTMLVideoElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const [frames, setFrames] = useState<ImageData[]>([]);
    const [videoDuration, setVideoDuration] = useState(0)
    const [timeoutId, setTimeoutId] = useState<NodeJS.Timeout | null>(null);
    const [isPlaying, setIsPlaying] = useState("0");
    const [isLoading, setIsLoading] = useState(true)
    const [isReversed, setIsReversed] = useState(false)

    const FPS = 30

    // Read all the frames from video and store it in frames state
    const handleVideoLoaded = () => {
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
            setVideoDuration(video.duration)
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

    useEffect(() => {
        const videoElement = videoRef.current;
        if (videoElement)
            videoElement.src = "/assets/video.mp4";
    }, [])

    useEffect(() => {
        if (isPlaying === "0" && currentVideo?.url && !isReversed) {
            if (timeoutId)
                clearTimeout(timeoutId)
            setIsPlaying(currentVideo.url)
        }
        else if (frames.length > 0 && isPlaying === "0") {
            if (timeoutId)
                clearTimeout(timeoutId)
            setIsPlaying("1")
        }
    }, [frames, isPlaying, currentVideo, timeoutId, isReversed])

    useEffect(() => {
        if (isPlaying === "1") {
            const canvas = canvasRef.current;
            if (!canvas || frames.length === 0) return;
            const context = canvas.getContext('2d');
            if (!context) return;
            let currentFrameIndex = isReversed ? frames.length - 1 : 0;
            const direction = isReversed ? -1 : 1;
            const frameDelay = 1000 / FPS;

            const playFrames = () => {
                context.putImageData(frames[currentFrameIndex], 0, 0);
                currentFrameIndex += direction;
                if (currentFrameIndex === frames.length - 1 || currentFrameIndex === 0) {
                    setIsReversed(prev => !prev)
                    setIsPlaying("0")
                    return
                }
                const timeoutId = setTimeout(playFrames, frameDelay);
                setTimeoutId(timeoutId)
            };

            playFrames();
        } else if (isPlaying && isPlaying !== "0" && isPlaying !== "1" && !isReversed) {
            console.log('play')
            const video = document.createElement('video');
            video.src = isPlaying;

            const canvas = canvasRef.current;
            if (!canvas) return;
            const context = canvas.getContext('2d');
            if (!context) return;

            video.addEventListener('play', () => {
                const drawFrame = () => {
                    if (video.paused || video.ended) {
                        popVideo();
                        const duration = video.duration
                        console.log(duration, videoDuration, Math.round(duration / videoDuration) % 2)
                        if (duration <= videoDuration || Math.round(duration / videoDuration) % 2 === 1) {
                            setIsReversed(true)
                        } else {
                            setIsReversed(false)
                        }
                        setIsPlaying("0")
                        return
                    };
                    context.drawImage(video, 0, 0, canvas.width, canvas.height);
                    requestAnimationFrame(drawFrame);
                };
                drawFrame();
            });

            video.play()
        }
    }, [frames, isPlaying, popVideo, isReversed, videoDuration])


    return (
        <>
            <div className={`size-full relative`}>
                {
                    isLoading ?
                        <div className="absolute inset-0 flex items-center justify-center">
                            <svg className="text-gray-300 animate-spin" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg"
                                width="48" height="48">
                                <path
                                    d="M32 3C35.8083 3 39.5794 3.75011 43.0978 5.20749C46.6163 6.66488 49.8132 8.80101 52.5061 11.4939C55.199 14.1868 57.3351 17.3837 58.7925 20.9022C60.2499 24.4206 61 28.1917 61 32C61 35.8083 60.2499 39.5794 58.7925 43.0978C57.3351 46.6163 55.199 49.8132 52.5061 52.5061C49.8132 55.199 46.6163 57.3351 43.0978 58.7925C39.5794 60.2499 35.8083 61 32 61C28.1917 61 24.4206 60.2499 20.9022 58.7925C17.3837 57.3351 14.1868 55.199 11.4939 52.5061C8.801 49.8132 6.66487 46.6163 5.20749 43.0978C3.7501 39.5794 3 35.8083 3 32C3 28.1917 3.75011 24.4206 5.2075 20.9022C6.66489 17.3837 8.80101 14.1868 11.4939 11.4939C14.1868 8.80099 17.3838 6.66487 20.9022 5.20749C24.4206 3.7501 28.1917 3 32 3L32 3Z"
                                    stroke="currentColor" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"></path>
                                <path
                                    d="M32 3C36.5778 3 41.0906 4.08374 45.1692 6.16256C49.2477 8.24138 52.7762 11.2562 55.466 14.9605C58.1558 18.6647 59.9304 22.9531 60.6448 27.4748C61.3591 31.9965 60.9928 36.6232 59.5759 40.9762"
                                    stroke="currentColor" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" className="text-gray-900">
                                </path>
                            </svg>
                        </div>
                        : null
                }

                <video
                    ref={videoRef}
                    className="size-full absolute"
                    poster="/assets/image.png"
                    style={{ visibility: 'hidden' }}
                    onLoadedData={handleVideoLoaded}
                    muted
                />
                <div className='size-full absolute flex justify-center'>
                    <canvas ref={canvasRef}></canvas>
                </div>

            </div>
        </>
    );
}