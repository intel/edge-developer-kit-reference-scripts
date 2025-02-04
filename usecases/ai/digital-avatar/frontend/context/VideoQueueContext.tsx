// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import React, { createContext, useState, ReactNode, useMemo, useCallback } from 'react';

interface Video {
    id: number;
    url?: string | undefined;
}

export interface VideoQueueContextProps {
    queue: Video[];
    addVideo: (video: Video) => void;
    popVideo: () => void;
    currentVideo: Video | undefined;
    updateVideo: (id: number, url: string) => void;
}

export const VideoQueueContext = createContext<VideoQueueContextProps>({} as VideoQueueContextProps);

export const VideoQueueProvider = ({ children }: { children: ReactNode }) => {
    const [queue, setQueue] = useState<Video[]>([]);

    const addVideo = (video: Video) => {
        setQueue((prevQueue) => [...prevQueue, video]);
    };

    const updateVideo = (id: number, url: string) => {
        setQueue((prevQueue) => {
            return prevQueue.map((item) => {
                if (item.id === id) {
                    return { ...item, url }
                }
                return { ...item }
            })
        });
    };

    const popVideo = useCallback(() => {
        setQueue((prevQueue) => { return prevQueue.slice(1) });
    }, []);


    const currentVideo = useMemo(() => {
        return queue[0];
    }, [queue])
    return (
        <VideoQueueContext.Provider value={{ queue, addVideo, popVideo, currentVideo, updateVideo }}>
            {children}
        </VideoQueueContext.Provider>
    );
};