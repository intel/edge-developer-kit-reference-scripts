// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client";

// Framework import
import React, { useEffect, useState } from "react";
import {
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Slider,
  Stack,
  Typography,
} from "@mui/material";
import { enqueueSnackbar } from "notistack";
import { type CustomFile } from "@/types/dropzone";
import { useCreateTextEmbeddings, useDeleteTextEmbeddingBySource } from "@/hooks/api-hooks/use-dataset-api";
import InfoTypography from "@/components/common/InfoTypography";
import Dropzone from "@/components/common/Dropzone/Dropzone";

export default function AddDocumentDialog({
  source,
  isOpen,
  onClose,
}: {
  source: string[];
  isOpen: boolean;
  onClose: VoidFunction;
}): React.JSX.Element {
  const [isUploading, setIsUploading] = useState<boolean>(false);
  const [isUploadError, setIsUploadError] = useState<boolean>(false);
  const [selectedFiles, setSelectedFiles] = useState<CustomFile[]>([]);
  const [chunkSize, setChunkSize] = useState<number>(1024);
  const [chunkOverlap, setChunkOverlap] = useState<number>(0);
  const [selectedSource, setSelectedSource] = useState<string>("");
  const createTextEmbeddings = useCreateTextEmbeddings();
  const deleteTextEmbeddingBySource = useDeleteTextEmbeddingBySource();

  useEffect(() => {
    if (source?.length > 0) {
      setSelectedSource(source[0]);
    }
  }, [source]);

  const resetState = (): void => {
    setChunkSize(1024);
    setChunkOverlap(0);
    setIsUploading(false);
    setIsUploadError(false);
    setSelectedFiles([]);
    setSelectedSource("");
  };

  const handleSourceChange = (newSource: string): void => {
    setSelectedSource(newSource);
  };

  const handleDeleteSource = (): void => {
    deleteTextEmbeddingBySource.mutate(
      { source: selectedSource },
      {
        onSuccess: (response) => {
          if (response.status) {
            enqueueSnackbar(`Embedding deleted successfully.`, {
              variant: "success",
            });
            resetState();
            onClose();
          } else {
            enqueueSnackbar(
              `Fail to delete embeddings, please contact admin.`,
              { variant: "error" }
            );
          }
        },
      }
    );
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
      { chunkSize, chunkOverlap, data: formData },
      {
        onSuccess: (response) => {
          if (response.status) {
            enqueueSnackbar(`Embedding created successfully.`, {
              variant: "success",
            });
            resetState();
            onClose();
          } else {
            enqueueSnackbar(
              `Fail to create embeddings, please contact admin.`,
              { variant: "error" }
            );
            resetState();
          }
        },
      }
    );
  };

  return (
    <Dialog open={isOpen} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle sx={{ fontWeight: "bold" }}>Document Management</DialogTitle>
      <Divider />
      <DialogContent>
        <Stack gap="1rem">
          {source?.length > 0 ? (
            <Stack gap="1rem">
              <InfoTypography>Available documents</InfoTypography>
              <FormControl fullWidth>
                <InputLabel id="docs-select-label">Docs</InputLabel>
                <Select
                  labelId="docs-select-label"
                  id="docs-select"
                  value={selectedSource}
                  label="Docs"
                  onChange={(event) => {
                    handleSourceChange(event.target.value);
                  }}
                >
                  {source.map((doc: string, index: number) => {
                    return (
                      <MenuItem key={index} value={doc}>
                        {doc}
                      </MenuItem>
                    );
                  })}
                </Select>
              </FormControl>
              <Stack direction="row" justifyContent="flex-end">
                <Button
                  variant="contained"
                  color="error"
                  onClick={handleDeleteSource}
                  disabled={selectedSource === ""}
                >
                  Delete
                </Button>
              </Stack>
              <Divider />
            </Stack>
          ) : null}
          <InfoTypography>Upload your enterprise documentation</InfoTypography>
          <Typography>Chunk Size</Typography>
          <Slider
            aria-label="chunk-size"
            value={chunkSize}
            step={1}
            onChange={(event, value) => {
              setChunkSize(value as number);
            }}
            valueLabelDisplay="auto"
            marks
            min={100}
            max={4096}
          />
          <Typography>Chunk Overlap</Typography>
          <Slider
            aria-label="chunk-overlap"
            value={chunkOverlap}
            step={10}
            onChange={(event, value) => {
              setChunkOverlap(value as number);
            }}
            valueLabelDisplay="auto"
            marks
            min={0}
            max={500}
          />
          <Dropzone
            files={selectedFiles}
            acceptFileType={{ "application/pdf": [".pdf"] }}
            setFieldValue={setFieldValue}
            onUpload={handleUpload}
            isUploading={isUploading}
            error={isUploadError}
          />
        </Stack>
      </DialogContent>
    </Dialog>
  );
}
