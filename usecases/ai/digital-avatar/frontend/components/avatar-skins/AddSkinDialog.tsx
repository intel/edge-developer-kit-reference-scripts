"use client"

import React, { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Plus } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { toast } from "sonner"
import Dropzone from "@/components/common/Dropzone/Dropzone"
import { type CustomFile } from "@/types/dropzone"
import { useCreateAvatarSkin } from "@/hooks/useLiveportrait"

export default function AddSkinDialog({ 
  refetchTask,
  setRefetchInterval,
  taskStatus
} : { 
  refetchTask: () => void,
  setRefetchInterval: (interval: number) => void,
  taskStatus?: string
}) {
  const [isDialogOpen, setIsDialogOpen] = useState<boolean>(false);
  const [skinName, setSkinName] = useState("")
  const [isProcessing, setIsProcessing] = useState(false)
  const [selectedFiles, setSelectedFiles] = useState<CustomFile[]>([])

  const avatarSkinMutation = useCreateAvatarSkin()

  const setFieldValue = (field: string, value: CustomFile[] | null) => {
    setSelectedFiles(value ? value.slice(0, 1) : [])
  }

  const handleUpload = async () => {
    const file = selectedFiles[0]
    if (!file || !skinName.trim()) {
      toast.error("Please select a file and enter a skin name")
      return
    }
    setIsProcessing(true)
    if (file.type === "video/mp4") {
      // For video files, set a shorter refetch interval
      setRefetchInterval(2000)
    } else if (file.type === "image/png") {
      setRefetchInterval(15000)
    }

    try {
      const formData = new FormData()
      formData.append("source", file)
      formData.append("skin_name", skinName)
      avatarSkinMutation.mutate({ data: formData })
      toast.success("Started skin creation process...")
    } catch (error) {
      console.error("Upload error:", error)
      toast.error("Upload failed: Failed to create skin. Please try again.")
    }
  }

  useEffect(() => {
    if (avatarSkinMutation.isSuccess || avatarSkinMutation.isError) {
      setSelectedFiles([])
      setSkinName("")
      setIsProcessing(false)
      setIsDialogOpen(false)
      refetchTask()
    }
  }, [avatarSkinMutation.isSuccess, avatarSkinMutation.isError, refetchTask])
  
  return (
    <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
      <Button disabled={taskStatus === "IN_PROGRESS"} className="rounded-full" onClick={() => setIsDialogOpen(!isDialogOpen)}>
        <Plus />
      </Button>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Add New Skin</DialogTitle>
          <DialogDescription>
            Upload a video (.mp4) or image (.png) file to add a new avatar skin.
          </DialogDescription>
          <ul className="list-disc list-inside ml-5 space-y-1 text-muted-foreground text-sm">
            <li>If there is an existing skin with the same name, the skin will be replaced with the newly added skin.</li>
            <li>Videos will be trimmed to 5 seconds, and images will be converted to animated videos.</li>
          </ul>
        </DialogHeader>
        <div className="space-y-2">
          <Label htmlFor="skinName">Skin Name</Label>
          <Input
            id="skinName"
            placeholder="Enter skin name..."
            value={skinName}
            onChange={(e) => setSkinName(e.target.value)}
          />
        </div>

        <div className="space-y-2">
          <Label>File Upload</Label>
          <Dropzone
            files={selectedFiles}
            setFieldValue={setFieldValue}
            acceptFileType={{ "video/mp4": [".mp4"], "image/png": [".png"] }}
            isMultiple={false}
            isUploading={isProcessing}
            onUpload={handleUpload}
            error={false}
          />
        </div>
      </DialogContent>
    </Dialog>
  )
}