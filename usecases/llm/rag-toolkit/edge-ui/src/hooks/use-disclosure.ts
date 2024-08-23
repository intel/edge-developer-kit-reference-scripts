'use client';

// Framework imports
import { useState } from 'react';

export const useDisclosure = (): {
  isOpen: boolean;
  onClose: VoidFunction;
  onOpenChange: (newIsOpen: boolean) => void;
} => {
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const closeModal = (): void => {
    setIsOpen(false);
  };
  const handleOpenChange = (newIsOpen: boolean): void => {
    setIsOpen(newIsOpen);
  };

  return {
    isOpen,
    onClose: closeModal,
    onOpenChange: handleOpenChange,
  };
};
