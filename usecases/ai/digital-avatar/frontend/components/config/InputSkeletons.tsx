import { Skeleton } from "../ui/skeleton"

export const SelectSkeleton = () => (
  <div className="space-y-2">
    <Skeleton className="h-4 w-20" />
    <Skeleton className="h-10 w-full" />
  </div>
)

export const SliderSkeleton = () => (
  <div className="space-y-2">
    <div className="flex justify-between">
      <Skeleton className="h-4 w-32" />
    </div>
    <Skeleton className="h-5 w-full" />
    <div className="flex justify-between">
      <Skeleton className="h-3 w-6" />
      <Skeleton className="h-3 w-6" />
      <Skeleton className="h-3 w-6" />
    </div>
  </div>
)

export const TextareaSkeleton = () => (
  <div className="space-y-2">
    <Skeleton className="h-4 w-32" />
    <Skeleton className="h-[100px] w-full" />
  </div>
)

export const RadioGroupSkeleton = () => (
  <div className="space-y-2">
    <Skeleton className="h-4 w-20" />
    <div className="flex space-x-4">
      <div className="flex items-center space-x-2">
        <Skeleton className="h-4 w-4 rounded-full" />
        <Skeleton className="h-4 w-16" />
      </div>
      <div className="flex items-center space-x-2">
        <Skeleton className="h-4 w-4 rounded-full" />
        <Skeleton className="h-4 w-16" />
      </div>
      <div className="flex items-center space-x-2">
        <Skeleton className="h-4 w-4 rounded-full" />
        <Skeleton className="h-4 w-16" />
      </div>
    </div>
  </div>
)

export const SwitchSkeleton = () => (
  <div className="flex items-center space-x-2">
    <Skeleton className="h-6 w-11 rounded-full" />
    <Skeleton className="h-4 w-24" />
  </div>
)