// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client"


import { Plus } from "lucide-react"
import { useState } from "react"
import { toast } from "sonner"
import Dropzone from "@/components/common/Dropzone/Dropzone"
import { Button } from "@/components/ui/button"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { CustomFile } from "@/types/dropzone"
import type React from "react"
import { useCreateTextEmbeddings } from "@/hooks/useLLM"

export default function AddDocumentDialog({ disabled = false, refetchTask }: { disabled?: boolean, refetchTask: () => void }) {
    const [isDialogOpen, setIsDialogOpen] = useState<boolean>(false);
    const [isUploading, setIsUploading] = useState<boolean>(false);
    const [isUploadError, setIsUploadError] = useState<boolean>(false);
    const [selectedFiles, setSelectedFiles] = useState<CustomFile[]>([]);
    const createTextEmbeddings = useCreateTextEmbeddings();

    const resetState = (): void => {
        setIsUploading(false);
        setIsUploadError(false);
        setSelectedFiles([]);
    };

    const setFieldValue = (field: string, value: CustomFile[]): void => {
        setSelectedFiles(value);
    };

    const handleUpload = (): void => {
        setIsUploading(true);
        const formData = new FormData();
        if (Array.isArray(selectedFiles)) {
            selectedFiles.forEach((file) => {
                formData.append("files", file);
            });
        } else {
            formData.append("files", selectedFiles);
        }
        createTextEmbeddings.mutate(
            { chunkSize: 512, chunkOverlap: 0, data: formData },
            {
                onSuccess: (response) => {
                    if (response.status) {
                        toast.success("Started text embedding creation process...")
                        setIsDialogOpen(false);
                    } else {
                        toast.error("Failed to create text embeddings. Please try again.");
                    }
                },
                onError: () => {
                    console.log("Add Document Error. Please check with admin.")
                },
                onSettled: () => {
                    resetState();
                    refetchTask();
                }
            }
        );
    };

    return (
        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <Button disabled={disabled} className="rounded-full" onClick={() => setIsDialogOpen(!isDialogOpen)}>
                <Plus />
            </Button>
            <DialogContent className="sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle>Document Management</DialogTitle>
                    <DialogDescription>Upload your documents for RAG (Retrieval Augmented Generation)</DialogDescription>
                </DialogHeader>
                <Dropzone
                    files={selectedFiles}
                    acceptFileType={{ "application/pdf": [".pdf"] }}
                    setFieldValue={setFieldValue}
                    onUpload={handleUpload}
                    isUploading={isUploading}
                    error={isUploadError}
                />
            </DialogContent>
        </Dialog>
    )
}