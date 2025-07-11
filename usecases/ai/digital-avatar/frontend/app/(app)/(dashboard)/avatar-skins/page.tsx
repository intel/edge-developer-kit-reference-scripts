// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client";

import AddSkinDialog from "@/components/avatar-skins/AddSkinDialog";
import ManageSkins from "@/components/avatar-skins/ManageSkins";
import { useGetAvatarSkinTask } from "@/hooks/useLiveportrait";
import { QueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner"

export default function DocumentList() {
    const queryClient = new QueryClient()
    const [pollTask, setPollTask] = useState(false);
    const [refetchInterval, setRefetchInterval] = useState(15000);
    const { data: taskData, refetch: refetchTask } = useGetAvatarSkinTask({ enabled: pollTask, refetchInterval: refetchInterval });

    const taskStatus = useMemo(() => {
        try {
            if (taskData && taskData.data) {
                return taskData.data.status
            }
        } catch (error) {
            console.error("Error parsing task data:", error);
        }
    }, [taskData])

    // Start polling when a task is running, stop when idle
    useEffect(() => {
        if (taskStatus === "IN_PROGRESS") {
            if (!pollTask) setPollTask(true);
        } else if (["COMPLETED", "FAILED", "IDLE"].includes(taskStatus)) {
            if (pollTask) {
                if (taskStatus === "COMPLETED") {
                    queryClient.invalidateQueries({ queryKey: ['avatar-skins'] })
                    toast.success("Avatar skin created successfully!");
                } else if (taskStatus === "FAILED") {
                    toast.error("Failed to create avatar skin. Please try again.");
                }
                setPollTask(false)
            }
        }
    }, [taskStatus, pollTask, queryClient]);

    return (
        <div className="container mx-auto p-4 md:p-6">
            <h1 className="text-2xl font-bold mb-2">Avatar Skins</h1>
            <div className="mb-4 flex items-center justify-between">
                <p className="text-gray-600">Create custom avatar skins by uploading videos or images.</p>
                <AddSkinDialog refetchTask={refetchTask} setRefetchInterval={setRefetchInterval} taskStatus={taskStatus} />
            </div>

            <ManageSkins taskData={taskData?.data} />
        </div>
    )
}

