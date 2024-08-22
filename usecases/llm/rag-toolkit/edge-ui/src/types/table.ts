export interface TableProps {
  headers: TableHeaderProps[];
  data: Record<string, any>[];
  dataLength?: number;
  title?: string;
  filterKey?: string;
  back?: { label: string; onOpen: VoidFunction };
  addData?: { label: string; onOpen: VoidFunction };
  enablePagination?: boolean;
  enableActions?: boolean;
  classNames?: Record<string, string>;
  td?: string;
  handleDeleteSelected?: (ids: number[]) => void;
  rowClicked?: (id: number | string) => void;
}

export interface TableHeaderProps {
  id: string;
  label: string;
  sort: boolean;
  numeric: boolean;
}
