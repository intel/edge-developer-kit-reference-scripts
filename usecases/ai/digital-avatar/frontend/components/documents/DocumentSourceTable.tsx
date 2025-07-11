// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client";

import { Trash2 } from "lucide-react";
import { useContext, useMemo, useState, type MouseEvent } from "react";
import { toast } from "sonner"
import { ConfirmationContext } from "@/context/ConfirmationContext";
import { useDeleteTextEmbeddingBySource } from "@/hooks/useLLM";


function DeleteButton({
    id,
    isDeleting,
    handleDelete,
}: {
    id: string;
    isDeleting: boolean;
    handleDelete: (ev: MouseEvent<HTMLButtonElement>, id: string) => void;
}): React.JSX.Element {
    return !isDeleting ? (
        <button
            onClick={(ev: React.MouseEvent<HTMLButtonElement, globalThis.MouseEvent>) => {
                handleDelete(ev, id);
            }}
            className="text-red-500 hover:text-red-700"
            aria-label="Delete document"
        >
            <Trash2 size={20} />
        </button>
    ) : (
        <div className="size-5 border-2 border-red-500 border-t-transparent rounded-full animate-spin" />
    );
}

const DocumentSourceTable = ({
    data,
    refetch,
}: {
    data: string[];
    refetch: () => void;
}) => {
    const [deletingIds, setDeletingIds] = useState<string[]>([]);
    const { openConfirmationDialog } = useContext(ConfirmationContext);
    const deleteTextEmbeddingBySource = useDeleteTextEmbeddingBySource();

    const formattedData = useMemo(() => {
        const handleDelete = (
            ev: { stopPropagation: () => void; },
            id: string
        ): void => {
            ev.stopPropagation();
            openConfirmationDialog({
                title: "Delete Source",
                message: "Are you sure you want to delete?",
                onClick: () => {
                    confirmDelete(id);
                },
            });
        };

        const confirmDelete = (id: string): void => {
            setDeletingIds((prev) => [...prev, id]);
            deleteTextEmbeddingBySource.mutate(
                { source: id },
                {
                    onSuccess: (response) => {
                        if (response.status) {
                            toast.success("Source deleted successfully.")
                            refetch()
                        } else {
                            toast.success("Failed to delete source. Please check with admin.")
                        }
                    },
                    onSettled: () => {
                        setDeletingIds((prev) => prev.filter((p) => p !== id));
                    },
                }
            );
        };

        return data.map((d) => {
            return {
                id: d,
                source: d,
                actions: (
                    <DeleteButton
                        id={d}
                        isDeleting={deletingIds.some((source) => source === d)}
                        handleDelete={handleDelete}
                    />
                ),
            };
        });
    }, [data, deleteTextEmbeddingBySource, deletingIds, openConfirmationDialog]);

    return (
        <div className="overflow-x-auto">
            <table className="min-w-full bg-white border border-gray-300">
                <thead>
                    <tr className="bg-gray-100">
                        <th className="py-2 px-4 border-b text-left">Source</th>
                        <th className="py-2 px-4 border-b text-left">Action</th>
                    </tr>
                </thead>
                <tbody>
                    {formattedData.map((data) => (
                        <tr key={data.id} className="hover:bg-gray-50">
                            <td className="py-2 px-4 border-b">{data.source}</td>
                            <td className="py-2 px-4 border-b items-center">
                                {data.actions}
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    )
}

export default DocumentSourceTable;