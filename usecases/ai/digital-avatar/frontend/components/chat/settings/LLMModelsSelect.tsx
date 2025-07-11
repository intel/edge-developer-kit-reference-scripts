// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

"use client"

import { Check, ChevronsUpDown } from "lucide-react"
import { useMemo, useState } from "react"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import {
    Command,
    CommandEmpty,
    CommandGroup,
    CommandInput,
    CommandItem,
    CommandList,
} from "@/components/ui/command"
import {
    Popover,
    PopoverContent,
    PopoverTrigger,
} from "@/components/ui/popover"
import Spinner from "@/components/ui/spinner"
import { useGetLLM, usePullLLM } from "@/hooks/useLLM"
import { cn } from "@/lib/utils"

export function LLMModelsSelect({ value, updateValue }: { value: string; updateValue: (value: string) => void }) {
    const { data: llmModelData } = useGetLLM()
    const [searchValue, setSearchValue] = useState("")
    const [open, setOpen] = useState(false)

    const updateOpen = (open: boolean) => {
        setOpen(open)
    }

    const pullLLM = usePullLLM()

    const llmModels = useMemo(() => {
        return llmModelData?.data ?? []
    }, [llmModelData])

    const handlePullLLM = () => {
        pullLLM.mutateAsync({ data: { model: searchValue } }).then((response) => {
            if (response.data.error) {
                toast.error(response.data.error)
            } else {
                toast.success("Model Pulled Successfully")
            }
        })
    }

    return (
        <Popover open={open} onOpenChange={updateOpen}>
            <PopoverTrigger asChild>
                <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={open}
                    className="w-[200px] justify-between"
                >
                    {value && llmModels
                        ? llmModels.find((models) => models.id === (value.includes(":") ? value : `${value}:latest`))?.id
                        : "Select Model"}
                    <ChevronsUpDown className="opacity-50" />
                </Button>
            </PopoverTrigger>
            <PopoverContent className="w-[200px] p-0">
                <Command>
                    <CommandInput value={searchValue} onValueChange={setSearchValue} placeholder="Search model..." className="h-9" />
                    <CommandList>
                        <CommandEmpty>
                            <div className="flex items-center gap-4 flex-col">
                                {
                                    pullLLM.isPending ?
                                        <div className="flex items-center gap-2">
                                            Pulling {searchValue}
                                            <Spinner size={20} />
                                        </div>
                                        :
                                        <>
                                            No Model Found
                                            <Button onClick={handlePullLLM}>Pull {searchValue}</Button>
                                        </>
                                }
                            </div>
                        </CommandEmpty>
                        <CommandGroup>
                            {llmModels && llmModels.map((model) => {
                                const modelName = model.id;
                                return (
                                    <CommandItem
                                        key={modelName}
                                        value={modelName}
                                        onSelect={(currentValue) => {
                                            updateValue(currentValue === value ? "" : currentValue)
                                            updateOpen(false)
                                        }}
                                    >
                                        {modelName}
                                        <Check
                                            className={cn(
                                                "ml-auto",
                                                value === modelName ? "opacity-100" : "opacity-0"
                                            )}
                                        />
                                    </CommandItem>
                                )
                            }

                            )}
                        </CommandGroup>
                    </CommandList>
                </Command>
            </PopoverContent>
        </Popover>
    )
}

export const maxDuration = 300
