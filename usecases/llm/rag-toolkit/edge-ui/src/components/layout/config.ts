import type { NavItemConfig } from '@/types/nav';
import { paths } from '@/paths';

export const navItems = [...paths.main] satisfies NavItemConfig[];
