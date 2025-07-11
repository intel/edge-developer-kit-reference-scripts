"use client"

import type React from "react"
import {
    SidebarProvider,
    Sidebar,
    SidebarHeader,
    SidebarContent,
    SidebarMenu,
    SidebarMenuItem,
    SidebarMenuButton,
    SidebarGroup,
    SidebarGroupLabel,
    SidebarGroupContent,
    SidebarInset,
    SidebarTrigger,
} from "@/components/ui/sidebar"
import { Zap, Clock, User, Settings, FileText, Shirt } from "lucide-react"
import Link from "next/link"

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
    return (
        <SidebarProvider>
            <AppSidebar />
            <SidebarInset>
                <header className="flex h-16 w-full shrink-0 items-center gap-2 border-b px-4 space-between">
                    <SidebarTrigger />
                </header>
                <main className="flex-1">{children}</main>
            </SidebarInset>
        </SidebarProvider>
    )
}

function AppSidebar() {
    const paths = [
        {
            label: "Application",
            type: "group",
            items: [
                {
                    icon: <User />,
                    url: "/",
                    length: "Avatar"
                },
                {
                    icon: <Shirt />,
                    url: "/avatar-skins",
                    length: "Avatar Skins"
                },
                {
                    icon: <FileText />,
                    url: "/documents",
                    length: "RAG Documents"
                },
                {
                    icon: <Settings />,
                    url: "/config",
                    length: "Configurations"
                },
            ]
        },
        {
            label: "Metrics",
            type: "group",
            items: [{
                icon: <Clock />,
                url: "/metric/performance-results",
                length: "Performance Results"
            }]
        }
    ]
    return (
        <Sidebar variant="inset">
            <SidebarHeader className="p-4">
                <div className="flex items-center gap-2">
                    <Zap className="h-6 w-6" />
                    <span className="text-lg font-bold">Digital Avatar</span>
                </div>
            </SidebarHeader>
            <SidebarContent>
                {
                    paths.filter(path => path.type === "group").map((path, index) => (
                        <SidebarGroup key={index}>
                            <SidebarGroupLabel>{path.label}</SidebarGroupLabel>
                            <SidebarGroupContent>
                                <SidebarMenu>
                                    {
                                        path.items.map((item, index) => (
                                            <SidebarMenuItem key={index}>
                                                <SidebarMenuButton asChild>
                                                    <Link href={item.url}>
                                                        {item.icon}
                                                        <span>{item.length}</span>
                                                    </Link>
                                                </SidebarMenuButton>
                                            </SidebarMenuItem>
                                        ))
                                    }
                                </SidebarMenu>
                            </SidebarGroupContent>
                        </SidebarGroup>
                    ))
                }
            </SidebarContent>
        </Sidebar>
    )
}

