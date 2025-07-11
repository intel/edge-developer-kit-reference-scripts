"use client"

import { Headphones, Mic } from "lucide-react";
import { Bar, BarChart, CartesianGrid, LabelList, PolarAngleAxis, PolarGrid, Radar, RadarChart, XAxis } from "recharts";

import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import {
    ChartConfig,
    ChartContainer,
    ChartTooltip,
    ChartTooltipContent,
} from "@/components/ui/chart";
import { usePerformanceResults } from "@/hooks/usePerformanceResult";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { ConfigSection } from "@/components/config/ConfigSection";
import { SelectedPipelineConfig } from "@/types/config";
import { PerformanceResultsMetadata } from "@/types/performanceResults";

const chartModuleConfig: Record<string, string> = {
    denoise: "Denoise",
    stt: "STT",
    llm: "LLM",
    tts: "TTS",
    lipsync: "Lipsync",
}

const defaultChartConfig: Record<string, { label: string; color: string }> = {
    config1: {
        label: "Config 1",
        color: "hsl(var(--chart-1))",
    },
    config2: {
        label: "Config 2",
        color: "hsl(var(--chart-2))",
    },
    config3: {
        label: "Config 3",
        color: "hsl(var(--chart-3))",
    },
} satisfies ChartConfig

const generateRandomColor = () => {
    const hue = Math.floor(Math.random() * 360); // Random hue value between 0 and 360
    const saturation = Math.floor(Math.random() * 50) + 50; // Saturation between 50% and 100%
    const lightness = Math.floor(Math.random() * 30) + 40; // Lightness between 40% and 70%
    return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
};

export default function LatencyDashboard() {
    const { data, isLoading, error } = usePerformanceResults();

    const chartConfig = data?.docs.reduce<Record<string, { label: string; color: string }>>((config, result) => {
        config[`config${result.id}`] = {
            label: `Config ${result.id}`,
            color: generateRandomColor(),
        };
        return config satisfies ChartConfig;
    }, {});

    const overviewChartData = Object.keys(chartModuleConfig).map((moduleKey) => {
        const moduleData: { module: string;[key: string]: number | string } = { module: chartModuleConfig[moduleKey] };

        data?.docs.forEach((result) => {
            let value = 0;

            if (moduleKey === "denoise") {
                value = result[moduleKey]?.inferenceLatency || 0;
            } else if (moduleKey === "stt") {
                value = (result[moduleKey]?.inferenceLatency || 0) + (result[moduleKey]?.httpLatency || 0);
            } else if (moduleKey === "llm") {
                value = result[moduleKey]?.totalLatency + result[moduleKey]?.ttft || 0;
            } else if (moduleKey === "tts" || moduleKey === "lipsync") {
                const results = result[moduleKey] || [];
                value = results.reduce((acc, item) => acc + (item.httpLatency || 0) + (item.inferenceLatency || 0), 0);
            }

            moduleData[`config${result.id}`] = value;
        });

        return moduleData;
    });
    
    // Get metrics comparison data
    const metricsComparisonChartData = data?.docs.map((result) => {
        const metadata = result.metadata as unknown as PerformanceResultsMetadata;
        const totalTTSLatency = (result.tts?.reduce((acc, item) => acc + (item.httpLatency || 0) + (item.inferenceLatency || 0), 0) || 0);
        const totalLipsyncLatency = (result.lipsync?.reduce((acc, item) => acc + (item.httpLatency || 0) + (item.inferenceLatency || 0), 0) || 0);
        const totalFramesGenerated = (result.lipsync?.reduce((acc, item) => {
            const metadata = item.metadata as { framesGenerated?: number };
            return acc + (metadata?.framesGenerated || 0);
        }, 0) || 0);

        return {
            name: `Config ${result.id}`,
            denoiseThroughput: result.denoise?.inferenceLatency ? (metadata.inputAudioDurationInSeconds || 1) / (result.denoise?.inferenceLatency) : null,
            sttThroughput: result.stt?.inferenceLatency && result.stt?.httpLatency ? (metadata.inputAudioDurationInSeconds || 1) / ((result.stt?.inferenceLatency) + (result.stt?.httpLatency)) : null,
            ttft: result.llm?.ttft || 0,
            llmThroughput: result.llm?.throughput || 0,
            ttsThroughput: (metadata.completionTokens ?? 0) / totalTTSLatency,
            lipsyncThroughput: totalFramesGenerated / totalLipsyncLatency,
            fill: chartConfig?.[`config${result.id}`]?.color || defaultChartConfig?.[`config${result.id}`]?.color,
        }
    })

    if (isLoading) return <div className="p-4 md:p-6">Loading...</div>;
    if (error) return <div className="p-4 md:p-6">Error loading performance results</div>;
    if (data?.totalDocs === 0) return <div className="p-4 md:p-6">No performance results found.</div>;

    return (
        <div className="space-y-6 max-w-3xl mx-auto p-4 md:p-6">
            <Card>
                <CardHeader className="items-center pb-4">
                    <CardTitle>Latency Overview</CardTitle>
                    <CardDescription>
                        Visualizing latencies in seconds of each module for each configuration
                    </CardDescription>
                </CardHeader>
                <CardContent className="pb-0 flex flex-row gap-4">
                    <ChartContainer
                        config={chartConfig || defaultChartConfig}
                        className="aspect-square max-h-[300px] flex-1"
                    >
                        <RadarChart
                            data={overviewChartData}
                            margin={{
                                right: 20,
                                left: 20,
                            }}
                        >
                            <ChartTooltip
                                cursor={false}
                                content={<ChartTooltipContent />}
                            />
                            <PolarAngleAxis dataKey="module" tick={{ fontSize: 12 }} tickLine={false} />
                            <PolarGrid radialLines={false} />
                            {data?.docs.map((result) => (
                                <Radar
                                    key={`config${result.id}`}
                                    dataKey={`config${result.id}`}
                                    fill={`var(--color-config${result.id})`}
                                    fillOpacity={0.6}
                                    dot={{
                                        r: 4,
                                        fillOpacity: 1,
                                    }}
                                    stroke={`var(--color-config${result.id})`}
                                    strokeWidth={2}
                                />
                            ))}
                        </RadarChart>
                    </ChartContainer>

                    <div className="flex-1 overflow-auto pb-4">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Module</TableHead>
                                    {data?.docs.map((result) => (
                                        <TableHead key={`latency-header-${result.id}`}>{`Config ${result.id}`}</TableHead>
                                    ))}
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {overviewChartData.map((row) => (
                                    <TableRow key={`latency-row-${row.module}`}>
                                        <TableCell>{row.module}</TableCell>
                                        {data?.docs.map((result) => (
                                            <TableCell key={`latency-cell-${row.module}-${result.id}`}>
                                                {row[`config${result.id}`] ? (row[`config${result.id}`] as number).toFixed(3) : "N/A"}
                                            </TableCell>
                                        ))}
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </div>
                </CardContent>
                <CardFooter className="flex-col gap-2 text-sm">
                    {/* <h3 className="text-sm font-medium">Metadata</h3>
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Config #</TableHead>
                                <TableHead>Input Audio Duration (s)</TableHead>
                                <TableHead>Prompt Tokens</TableHead>
                                <TableHead>Completion Tokens</TableHead>
                                <TableHead>Total Tokens</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {data?.docs.map((result) => {
                                const metadata = result.metadata as unknown as PerformanceResultsMetadata;
                                return (
                                    <TableRow key={`row-metadata-${result.id}`}>
                                        <TableCell>{`Config ${result.id}`}</TableCell>
                                        <TableCell>{metadata.inputAudioDurationInSeconds || "N/A"}</TableCell>
                                        <TableCell>{metadata.promptTokens || "N/A"}</TableCell>
                                        <TableCell>{metadata.completionTokens || "N/A"}</TableCell>
                                        <TableCell>{metadata.totalTokens || "N/A"}</TableCell>
                                    </TableRow>
                                )
                            })}
                        </TableBody>
                    </Table> */}
                </CardFooter>
            </Card>

            <Card>
                <CardHeader className="items-center pb-4">
                    <CardTitle>Metrics Comparison</CardTitle>
                    <CardDescription>
                        Visualizing the individual metrics of each module for each configuration
                    </CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">Denoise Throughput (s/s)</h3>
                            <ChartContainer
                                key={"denoise-throughput"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="denoiseThroughput" fill="#8884d8" name="Throughput (s/s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                            formatter={(value: number) => value.toFixed(3)}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>

                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">STT Throughput (s/s)</h3>
                            <ChartContainer
                                key={"stt-throughput"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="sttThroughput" fill="#8884d8" name="Throughput (s/s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                            formatter={(value: number) => value.toFixed(3)}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>

                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">LLM Time To First Token (s)</h3>
                            <ChartContainer
                                key={"llm-ttft"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="ttft" fill="#8884d8" name="TTFT (s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>

                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">LLM Throughput (token/s)</h3>
                            <ChartContainer
                                key={"llm-throughput"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="llmThroughput" fill="#8884d8" name="Throughput (token/s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                            formatter={(value: number) => value.toFixed(3)}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>

                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">TTS Throughput (token/s)</h3>
                            <ChartContainer
                                key={"tts-throughput"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="ttsThroughput" fill="#8884d8" name="Throughput (token/s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                            formatter={(value: number) => value.toFixed(3)}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>

                        <div className="flex flex-col gap-2 text-center">
                            <h3 className="text-xs font-medium">Lipsync Throughput (frame/s)</h3>
                            <ChartContainer
                                key={"lipsync-throughput"}
                                config={chartConfig || defaultChartConfig}
                                className="aspect-video"
                            >
                                <BarChart
                                    accessibilityLayer
                                    data={metricsComparisonChartData}
                                    margin={{
                                        top: 20,
                                        right: 20,
                                        left: 20,
                                        bottom: 20,
                                    }}
                                >
                                    <CartesianGrid vertical={false} />
                                    <XAxis
                                        dataKey="name"
                                        tickLine={false}
                                        tickMargin={10}
                                        axisLine={false}
                                    />
                                    <ChartTooltip
                                        cursor={false}
                                        content={<ChartTooltipContent />}
                                    />
                                    <Bar dataKey="lipsyncThroughput" fill="#8884d8" name="Throughput (frame/s)" radius={8}>
                                        <LabelList
                                            position="top"
                                            offset={12}
                                            className="fill-foreground"
                                            fontSize={12}
                                            formatter={(value: number) => value.toFixed(3)}
                                        />
                                    </Bar>
                                </BarChart>
                            </ChartContainer>
                        </div>
                    </div>
                </CardContent>
                <CardFooter className="flex-col gap-2 text-sm">
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Config #</TableHead>
                                <TableHead>Denoise Throughput (s/s)</TableHead>
                                <TableHead>STT Throughput (s/s)</TableHead>
                                <TableHead>LLM TTFT (s)</TableHead>
                                <TableHead>LLM Throughput (token/s)</TableHead>
                                <TableHead>TTS Throughput (token/s)</TableHead>
                                <TableHead>Lipsync Throughput (frame/s)</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {(metricsComparisonChartData ?? []).map((row) => {
                                return (
                                    <TableRow key={`row-metadata-${row.name}`}>
                                        <TableCell>{row.name}</TableCell>
                                        <TableCell>{row.denoiseThroughput ? row.denoiseThroughput.toFixed(3) : "N/A"}</TableCell>
                                        <TableCell>{row.sttThroughput ? row.sttThroughput.toFixed(3) : "N/A"}</TableCell>
                                        <TableCell>{row.ttft.toFixed(3)}</TableCell>
                                        <TableCell>{row.llmThroughput.toFixed(3)}</TableCell>
                                        <TableCell>{row.ttsThroughput.toFixed(3)}</TableCell>
                                        <TableCell>{row.lipsyncThroughput.toFixed(3)}</TableCell>
                                    </TableRow>
                                )
                            })}
                        </TableBody>
                    </Table>
                </CardFooter>
            </Card>

            <Card>
                <CardHeader className="items-center pb-4">
                    <CardTitle>Configurations</CardTitle>
                    <CardDescription>
                        Configurations details of each module
                    </CardDescription>
                </CardHeader>
                <CardContent className="pb-0 space-y-4">
                    <ConfigSection
                        title="Denoise"
                        icon={<Headphones className="h-5 w-5" />}
                    >
                        <div className="space-y-4">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Config #</TableHead>
                                        <TableHead>Device</TableHead>
                                        <TableHead>Model</TableHead>
                                        <TableHead>Precision</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {data?.docs.map((result) => {
                                        const sttResult = result.stt?.httpLatency || result.stt?.inferenceLatency;
                                        const config = sttResult ? result.config as unknown as SelectedPipelineConfig : null;
                                        return (
                                            <TableRow key={`row-denoise-${result.id}`}>
                                                <TableCell>{`Config ${result.id}`}</TableCell>
                                                <TableCell>{config?.denoiseStt?.denoise_device ?? "N/A"}</TableCell>
                                                <TableCell>{config?.denoiseStt?.denoise_model ?? "N/A"}</TableCell>
                                                <TableCell>{config?.denoiseStt?.denoise_model_precision ?? "N/A"}</TableCell>
                                            </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>
                        </div>
                    </ConfigSection>

                    <ConfigSection
                        title="STT"
                        icon={<Mic className="h-5 w-5" />}
                    >
                        <div className="space-y-4">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Config #</TableHead>
                                        <TableHead>Device</TableHead>
                                        <TableHead>Model</TableHead>
                                        <TableHead>Language</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {data?.docs.map((result) => {
                                        const sttResult = result.stt?.httpLatency || result.stt?.inferenceLatency;
                                        const config = sttResult ? result.config as unknown as SelectedPipelineConfig : null;
                                        return (
                                            <TableRow key={`row-stt-${result.id}`}>
                                                <TableCell>{`Config ${result.id}`}</TableCell>
                                                <TableCell>{config?.denoiseStt?.stt_device ?? "N/A"}</TableCell>
                                                <TableCell>{config?.denoiseStt?.stt_model ?? "N/A"}</TableCell>
                                                <TableCell>{config?.denoiseStt?.language ?? "N/A"}</TableCell>
                                            </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>
                        </div>
                    </ConfigSection>

                    <ConfigSection
                        title="LLM"
                        icon={<Mic className="h-5 w-5" />}
                    >
                        <div className="space-y-4">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Config #</TableHead>
                                        <TableHead>Model</TableHead>
                                        <TableHead>Temperature</TableHead>
                                        <TableHead>System Prompt</TableHead>
                                        <TableHead>Max Tokens</TableHead>
                                        <TableHead>Use RAG</TableHead>
                                        <TableHead>Embedding Device</TableHead>
                                        <TableHead>Reranker Device</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {data?.docs.map((result) => {
                                        const config = result.config as unknown as SelectedPipelineConfig;
                                        return (
                                            <TableRow key={`row-llm-${result.id}`}>
                                                <TableCell>{`Config ${result.id}`}</TableCell>
                                                <TableCell>{config?.llm?.llm_model ?? "N/A"}</TableCell>
                                                <TableCell>{config?.llm?.temperature ?? "N/A"}</TableCell>
                                                <TableCell>{config?.llm?.system_prompt ?? "N/A"}</TableCell>
                                                <TableCell>{config?.llm?.max_tokens ?? "N/A"}</TableCell>
                                                <TableCell>{config?.llm?.use_rag ? "Yes" : "No"}</TableCell>
                                                <TableCell>{config?.llm?.use_rag ? config?.llm?.embedding_device : "N/A"}</TableCell>
                                                <TableCell>{config?.llm?.use_rag ? config?.llm?.reranker_device : "N/A"}</TableCell>
                                            </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>
                        </div>
                    </ConfigSection>

                    <ConfigSection
                        title="TTS"
                        icon={<Headphones className="h-5 w-5" />}
                    >
                        <div className="space-y-4">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Config #</TableHead>
                                        <TableHead>Device</TableHead>
                                        <TableHead>Gender</TableHead>
                                        <TableHead>Speed</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {data?.docs.map((result) => {
                                        const config = result.config as unknown as SelectedPipelineConfig;
                                        return (
                                            <TableRow key={`row-tts-${result.id}`}>
                                                <TableCell>{`Config ${result.id}`}</TableCell>
                                                <TableCell>{config?.tts?.device ?? "N/A"}</TableCell>
                                                <TableCell>{config?.tts?.speaker ?? "N/A"}</TableCell>
                                                <TableCell>{config?.tts?.speed ?? "N/A"}</TableCell>
                                            </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>
                        </div>
                    </ConfigSection>

                    <ConfigSection
                        title="Lipsync"
                        icon={<Headphones className="h-5 w-5" />}
                    >
                        <div className="space-y-4">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Config #</TableHead>
                                        <TableHead>Device</TableHead>
                                        <TableHead>Model</TableHead>
                                        <TableHead>Use Enhancer</TableHead>
                                        <TableHead>Enhancer Device</TableHead>
                                        <TableHead>Enhancer Model</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {data?.docs.map((result) => {
                                        const config = result.config as unknown as SelectedPipelineConfig;
                                        return (
                                            <TableRow key={`row-lipsync-${result.id}`}>
                                                <TableCell>{`Config ${result.id}`}</TableCell>
                                                <TableCell>{config?.lipsync?.lipsync_device ?? "N/A"}</TableCell>
                                                <TableCell>{config?.lipsync?.lipsync_model ?? "N/A"}</TableCell>
                                                <TableCell>{config?.lipsync?.use_enhancer ? "Yes" : "No"}</TableCell>
                                                <TableCell>{config?.lipsync?.use_enhancer ? config?.lipsync?.enhancer_device : "N/A"}</TableCell>
                                                <TableCell>{config?.lipsync?.use_enhancer ? config?.lipsync?.enhancer_model : "N/A"}</TableCell>
                                            </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>
                        </div>
                    </ConfigSection>
                </CardContent>
                <CardFooter className="flex-col gap-2 text-sm"></CardFooter>
            </Card>
        </div>
    );
}