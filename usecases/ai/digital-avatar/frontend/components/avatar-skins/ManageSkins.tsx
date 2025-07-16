"use client"

import Image from "next/image"
import { useState, useEffect, useMemo } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Trash2, Download } from "lucide-react"
import { toast } from "sonner"
import { useGetLipsyncConfig, useUpdateLipsyncConfig } from "@/hooks/useLipsync"
import Spinner from "@/components/ui/spinner"
import { useDeleteAvatarSkin, useGetAvatarSkin } from "@/hooks/useAvatarSkin"
import { Skin } from "@/types/avatar-skins"

export default function ManageSkins({
  taskData
}: {
  taskData?: {
    type: string,
    skin_name: string,
    url: string | null,
    status: string,
    message: string,
  }
}) {
  const { data: skins, refetch } = useGetAvatarSkin()
  const deleteAvatarSkin = useDeleteAvatarSkin();
  const { data: lipsyncConfigData, refetch: refetchConfig } = useGetLipsyncConfig()
  const [updatingActiveSkin, setUpdatingActiveSkin] = useState<string | undefined>(undefined)
  const updateConfig = useUpdateLipsyncConfig()

  const lipsyncConfig = useMemo(() => {
    return lipsyncConfigData?.selected_config ?? undefined
  }, [lipsyncConfigData])

  useEffect(() => {
    if (taskData?.status === "COMPLETED") {
      refetch();
    }
  }, [taskData?.status, refetch]);

  const handleDelete = async (skinName: string) => {
    try {
      deleteAvatarSkin.mutate(
        { skinName },
        {
          onSuccess: (response) => {
            if (response.status) {
              toast.success("Skin deleted successfully!")
              refetch()
            } else {
              toast.error("Failed to delete skin. Please try again.")
            }
          }
        }
      );
    } catch (error) {
      console.error("Error deleting skin:", error)
      toast.error("Failed to delete skin. Please try again.")
    }
  }

  const activateSkin = async (skinName: string) => {
    if (!lipsyncConfig) {
      toast.error("Lipsync configuration not found")
      return
    }
    setUpdatingActiveSkin(skinName)
    updateConfig.mutate(
      { ...lipsyncConfig, avatar_skin: skinName },
      {
        onSuccess: () => {
          toast.success("Skin activated successfully!")
          refetchConfig()
          setUpdatingActiveSkin(undefined)
        },
        onError: () => {
          toast.error("Failed to activate skin. The request may have timed out, please try refreshing the page after a few seconds.")
        }
      }
    )
  }

  if (!skins || !lipsyncConfig) {
    return (
      <div className="text-center py-8">
        <p className="text-muted-foreground">Loading skins...</p>
      </div>
    )
  }
  if (skins.length === 0) {
    return (
      <div className="text-center py-8">
        <p className="text-muted-foreground">No skins created yet</p>
      </div>
    )
  }
  
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {skins.map((skin) => (
        <AvatarSkinCard
          key={skin.name}
          skin={skin}
          isActive={lipsyncConfig.avatar_skin === skin.name}
          onActivate={activateSkin}
          onDelete={handleDelete}
          updatingActiveSkin={updatingActiveSkin}
        />
      ))}
      {taskData && taskData.status === "IN_PROGRESS" &&
        <AvatarSkinCard
          skin={{ name: taskData.skin_name, url: taskData.url || "" }}
          isActive={false}
          progressMessage={taskData.message}
        />
      }
    </div>
  )
}

const AvatarSkinCard = ({
  skin,
  isActive,
  onActivate,
  onDelete,
  progressMessage,
  updatingActiveSkin
}: {
  skin: Skin;
  isActive: boolean;
  onActivate?: (skinName: string) => void;
  onDelete?: (skinName: string) => void;
  progressMessage?: string;
  updatingActiveSkin?: string;
}) => {
  return (
    <Card className={`overflow-hidden ${isActive ? "ring-2 ring-primary" : ""}`}>
      <div className="aspect-video bg-muted relative">
        {isActive && (
          <div className="absolute top-2 right-2 z-10 bg-primary text-primary-foreground px-2 py-1 rounded-md text-xs font-medium">
            Active
          </div>
        )}
        <div className="w-full h-full relative">
          {progressMessage && (
            <>
              <div className="absolute inset-0 z-10 flex items-center justify-center">
                <Spinner size={40} />
              </div>
            </>
          )}
          {skin.url.endsWith(".mp4") ? (
            <video
              src={`/api/liveportrait/v1/skin/${skin.url}`}
              className={`w-full h-full ${progressMessage ? 'opacity-60' : ''}`}
              muted
              loop
              onMouseEnter={progressMessage ? undefined : (e) => { try { e.currentTarget.play(); } catch {} }}
              onMouseLeave={progressMessage ? undefined : (e) => { try { e.currentTarget.pause(); } catch {} }}
            />
          ) : (
            <Image
              src={`/api/liveportrait/v1/skin/${skin.url}`}
              alt={skin.name}
              width={512}
              height={288}
              className={`w-full h-full object-contain ${progressMessage ? 'opacity-60' : ''}`}
            />
          )}
        </div>
      </div>
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold truncate">{skin.name}</h3>
          </div>
          <div className="flex gap-2">
            {!isActive && onActivate && (
              <Button disabled={Boolean(updatingActiveSkin)} size="sm" variant="outline" onClick={() => onActivate(skin.name)}>
                {updatingActiveSkin === skin.name ? (
                  <Spinner size={16} />
                ) : (
                  "Use"
                )}
              </Button>
            )}
            {!progressMessage ? (
              <Button size="sm" variant="outline" onClick={() => window.open(`/api/liveportrait/v1/skin/${skin.url}`, "_blank")}>
                <Download className="h-4 w-4" />
              </Button>
            ) : <p className="text-gray-600">{progressMessage}</p>}
            {onDelete && skin.name !== "default" && (
              <Button disabled={isActive} size="sm" variant="destructive" onClick={() => onDelete(skin.name)}>
                <Trash2 className="h-4 w-4" />
              </Button>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
