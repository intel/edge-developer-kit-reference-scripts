// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client";

import AddDocumentDialog from "@/components/documents/AddDocumentDialog";
import DocumentSourceTable from "@/components/documents/DocumentSourceTable";
import { Skeleton } from "@/components/ui/skeleton";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { useGetDatasetEmbeddingSources, useGetTextEmbeddingTask } from "@/hooks/useLLM";
import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner"

export default function DocumentList() {
    const [pollTask, setPollTask] = useState(false);
    const { data: taskData, refetch: refetchTask } = useGetTextEmbeddingTask({ enabled: pollTask });
    const { status, data: source, refetch: refetchTextEmbeddingSources } = useGetDatasetEmbeddingSources();

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
                    refetchTextEmbeddingSources();
                    toast.success("Text embeddings created successfully!");
                } else if (taskStatus === "FAILED") {
                    toast.error("Failed to create Text embeddings. Please try again.");
                }
                setPollTask(false)
            }
        }
    }, [taskStatus, pollTask]);
    
    return (
        <div className="container mx-auto p-4 md:p-6">
            <h1 className="text-2xl font-bold mb-2">Documents</h1>
            <div className="mb-4 flex items-center justify-between">
                <p className="text-gray-600">Create your vector database by uploading your documents.</p>
                <TooltipProvider>
                    <Tooltip>
                        <TooltipTrigger asChild>
                            <span>
                                <AddDocumentDialog 
                                    disabled={taskStatus === "IN_PROGRESS"}
                                    refetchTask={refetchTask} 
                                />
                            </span>
                        </TooltipTrigger>
                        {taskStatus === "IN_PROGRESS" && (
                            <TooltipContent>
                                <p>{taskData?.data.message}</p>
                            </TooltipContent>
                        )}
                    </Tooltip>
                </TooltipProvider>
            </div>
            {source?.data && taskStatus ? (
                (source.data && source.data.length > 0) || (taskStatus === "IN_PROGRESS") ? (
                    <DocumentSourceTable data={status ? source?.data ?? [] : []} taskData={taskData?.data} refetch={refetchTextEmbeddingSources} />
                ) : (
                    <div className="p-4 md:p-6">No RAG documents found.</div>
                )
            ) : <Skeleton className="h-[100px] w-full" />}
        </div>
    )
}

