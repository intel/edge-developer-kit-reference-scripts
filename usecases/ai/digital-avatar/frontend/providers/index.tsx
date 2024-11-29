"use client"

import { VideoQueueProvider } from "@/context/VideoQueueContext";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

export default function Providers({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    const queryClient = new QueryClient()
    return (
        <QueryClientProvider client={queryClient}>
            <VideoQueueProvider>
                {children}
            </VideoQueueProvider>
        </QueryClientProvider>
    )
}