import { type ReactElement, type ReactNode } from 'react';

export interface TabsProps {
  children?: ReactElement | ReactNode | string;
  value: string | number;
  index: number;
}
