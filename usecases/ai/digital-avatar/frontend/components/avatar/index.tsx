// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { useEffect, useMemo, useRef, useState } from 'react';

import useVideoQueue from '@/hooks/useVideoQueue';
import { useGetLipsyncConfig } from '@/hooks/useLipsync';

export default function Avatar() {
    const { isLoading: isFramesLoading, handleVideoLoaded, updateRefs } = useVideoQueue();
    const { data: lipsyncConfigData } = useGetLipsyncConfig()
    const [isVertical, setIsVertical] = useState(false);
    const videoRef = useRef<HTMLVideoElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);

    const lipsyncActiveSkin = useMemo(() => {
        return lipsyncConfigData?.selected_config.avatar_skin ?? undefined
    }, [lipsyncConfigData])

    const handleLoadedMetadata = () => {
        if (videoRef.current) {
            const { videoWidth, videoHeight } = videoRef.current;
            setIsVertical(videoHeight > videoWidth);
        }
    };

    useEffect(() => {
        if (videoRef.current && canvasRef.current) {
            updateRefs(videoRef.current, canvasRef.current)
        }
    }, [videoRef, canvasRef, updateRefs])

    useEffect(() => {
        const videoElement = videoRef.current;
        if (videoElement && lipsyncActiveSkin) {
            videoElement.src = `/api/liveportrait/v1/skin/${lipsyncActiveSkin}.mp4`;
            videoElement.load();
        }
    }, [lipsyncActiveSkin])

    useEffect(() => {
        return () => {
            updateRefs(null, null); // Clear references on unmount
        };
    }, []);

    return (
        <>
            <div className={`size-full relative`}>
                {
                    isFramesLoading ?
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
                    style={{ visibility: 'hidden' }}
                    onLoadedData={handleVideoLoaded}
                    onLoadedMetadata={handleLoadedMetadata}
                    muted
                />
                <div className='size-full absolute flex justify-center'>
                    <canvas ref={canvasRef} className={`${isVertical ? 'h-full w-auto' : 'w-full h-auto'} object-contain`}></canvas>
                </div>

            </div>
        </>
    );
}