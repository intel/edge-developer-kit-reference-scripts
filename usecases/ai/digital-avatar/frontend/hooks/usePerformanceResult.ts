import { toast } from "sonner"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { PerformanceResult } from "@/payload-types"
import { PayloadResponse } from "../types/payload"

export const usePerformanceResults = () => {
  return useQuery<PayloadResponse<PerformanceResult>>({
    queryKey: ["performance-results"],
    queryFn: async () => {
      // Simulate a delay
      await new Promise<void>((resolve) => setTimeout(()=>{resolve()}, 1000))

      const response = await fetch("/api/performance-results?limit=0")
      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.message || "Failed to fetch performance-results")
      }
      return response.json() as Promise<PayloadResponse<PerformanceResult>>
    }
  })
}

export const useCreatePerformanceResult = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (newPerformanceResult: Partial<PerformanceResult>) => {
      const response = await fetch("/api/performance-results", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(newPerformanceResult)
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.message || "Failed to create performance-result")
      }

      return response.json() as Promise<PerformanceResult>
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["performance-results"] })
    },
    onError: (error: any) => {
      console.error("Error creating performance-result:", error)
    }
  })
}

export const useDeletePerformanceResult = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (performanceResultId: number) => {
      const url = new URL(`/api/performance-results/${performanceResultId}`, window.location.origin)
      const response = await fetch(url, {
        method: "DELETE"
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.message || "Failed to delete performance-result")
      }

      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["performance-results"] })
      toast.success("Performance-result deleted successfully")
    },
    onError: (error: any) => {
      console.error("Error deleting performance-result:", error)
      toast.error(error.message || "Failed to delete performance-result")
    }
  })
}