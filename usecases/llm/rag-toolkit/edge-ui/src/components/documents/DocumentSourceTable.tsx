"use client";

// Framework
import React, { useContext, useMemo, useState, type MouseEvent } from "react";
import { usePathname, useRouter } from "next/navigation";
import { Delete } from "@mui/icons-material";
import { CircularProgress, IconButton } from "@mui/material";
import { enqueueSnackbar } from "notistack";
import { ConfirmationContext } from "@/contexts/ConfirmationContext";
import { type TableHeaderProps } from "@/types/table";
import { useDeleteTextEmbeddingBySource } from "@/hooks/api-hooks/use-dataset-api";
import TableTemplate from "../common/TableTemplate";

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
    <IconButton
      color="error"
      onClick={(ev) => {
        handleDelete(ev, id);
      }}
    >
      <Delete />
    </IconButton>
  ) : (
    <CircularProgress size={20} />
  );
}

export default function DocumentSourceTable({
  data,
}: {
  data: string[];
}): React.JSX.Element {
  const [deletingIds, setDeletingIds] = useState<string[]>([]);
  const { openConfirmationDialog } = useContext(ConfirmationContext);
  const deleteTextEmbeddingBySource = useDeleteTextEmbeddingBySource();
  const pathname = usePathname();
  const router = useRouter();

  const headers: TableHeaderProps[] = [
    {
      id: "source",
      label: "Source",
      sort: false,
      numeric: false,
    },
  ];

  const formattedData = useMemo(() => {
    const handleDelete = (
      ev: MouseEvent<HTMLButtonElement>,
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
              enqueueSnackbar(`Source deleted successfully.`, {
                variant: "success",
              });
            } else {
              enqueueSnackbar(
                "Failed to delete source. Please check with admin.",
                { variant: "error" }
              );
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

  const handleRowClick = (id: string | number): void => {
    router.push(`${pathname}/${id}`);
  };

  return (
    <TableTemplate
      headers={headers}
      data={formattedData}
      enableActions
      rowClicked={handleRowClick}
      enablePagination
    />
  );
}
