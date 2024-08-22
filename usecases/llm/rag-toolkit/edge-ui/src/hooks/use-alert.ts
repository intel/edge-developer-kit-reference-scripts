'use client';

import { enqueueSnackbar } from 'notistack';

export function alert(message: string): void {
  enqueueSnackbar(message, { variant: 'error' });
}
