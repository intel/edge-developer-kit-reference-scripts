// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use server";


import { getDatasetEmbeddingSourcesAPI } from "@/api/dataset";
import AddDocumentDialog from "@/components/documents/AddDocumentDialog";
import DocumentSourceTable from "@/components/documents/DocumentSourceTable";

export default async function DocumentList() {
    const { status, data: source } = await getDatasetEmbeddingSourcesAPI();

    return (
        <div className="container mx-auto p-4 md:p-6">
            <h1 className="text-2xl font-bold mb-2">Documents</h1>
            <div className="mb-4 flex items-center justify-between">
                <p className="text-gray-600">Create your vector database by uploading your documents.</p>
                <AddDocumentDialog />
            </div>
            <DocumentSourceTable data={status ? source : []} />
        </div>
    )
}

