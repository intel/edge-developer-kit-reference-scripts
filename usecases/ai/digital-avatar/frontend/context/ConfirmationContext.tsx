// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

'use client';

import React, { createContext, useCallback, useState, type ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';

type ConfirmationTypes = 'error' | 'inherit' | 'primary' | 'secondary' | 'success' | 'info' | 'warning';
interface ConfirmationContextProps {
    openConfirmationDialog: (data: {
        title?: string;
        message?: string;
        onClick: (args?: any) => void;
        type?: ConfirmationTypes;
    }) => void;
    updateOpen: (status: boolean) => void;
}

export const ConfirmationContext = createContext<ConfirmationContextProps>({} as ConfirmationContextProps);

export function ConfirmationProvider({ children }: { children: ReactNode }): React.JSX.Element {
    const [open, setOpen] = useState(false);
    const [dialogDetails, setDialogDetails] = useState<{
        title: string;
        message: string;
        type: ConfirmationTypes;
        onClick: (args?: any) => void;
    }>({
        title: 'Confirmation',
        message: 'Are you sure you want to delete?',
        type: 'error',
        onClick: () => { },
    });

    const openConfirmationDialog = useCallback(
        (data: {
            title?: string;
            message?: string;
            onClick: VoidFunction;
            type?: 'error' | 'inherit' | 'primary' | 'secondary' | 'success' | 'info' | 'warning';
        }) => {
            setDialogDetails((prev) => {
                return { ...prev, ...data, type: data.type ?? 'error' };
            });
            setOpen(true);
        },
        []
    );

    const updateOpen = (status: boolean): void => {
        setOpen(status);
    };

    return (
        <ConfirmationContext.Provider value={{ openConfirmationDialog, updateOpen }}>
            {children}

            <Dialog open={open} onOpenChange={setOpen}>
                {open ? (
                    <>
                        <DialogContent className="sm:max-w-[425px]">
                            <DialogHeader>
                                <DialogTitle>{dialogDetails.title}</DialogTitle>
                            </DialogHeader>
                            {dialogDetails.message}

                            <div className='flex justify-between'>
                                <Button
                                    variant="outline"
                                    onClick={() => {
                                        updateOpen(false);
                                    }}
                                >
                                    Cancel
                                </Button>
                                <Button
                                    onClick={() => {
                                        dialogDetails.onClick();
                                        updateOpen(false);
                                    }}
                                    className='red'
                                >
                                    Confirm
                                </Button>
                            </div>
                        </DialogContent>
                    </>
                ) : null}
            </Dialog>
        </ConfirmationContext.Provider>
    );
}
