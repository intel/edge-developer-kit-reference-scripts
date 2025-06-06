// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client";

import AddDocumentDialog from "@/components/documents/AddDocumentDialog";
import DocumentSourceTable from "@/components/documents/DocumentSourceTable";
import { Skeleton } from "@/components/ui/skeleton";
import { useGetDatasetEmbeddingSources } from "@/hooks/useLLM";

export default function DocumentList() {
    const { status, data: source, refetch } = useGetDatasetEmbeddingSources();

    return (
        <div className="container mx-auto p-4 md:p-6">
            <h1 className="text-2xl font-bold mb-2">Documents</h1>
            <div className="mb-4 flex items-center justify-between">
                <p className="text-gray-600">Create your vector database by uploading your documents.</p>
                <AddDocumentDialog refetch={refetch} />
            </div>
            {source?.data ? (
                source.data && source.data.length > 0 ? (
                    <DocumentSourceTable data={status ? source.data : []} refetch={refetch} />
                ) : (
                    <div className="p-4 md:p-6">No RAG documents found.</div>
                )
            ) : (<Skeleton className="h-[100px] w-full" />)}
        </div>
    )
}

