import * as migration_20250605_185846 from './20250605_185846';

export const migrations = [
  {
    up: migration_20250605_185846.up,
    down: migration_20250605_185846.down,
    name: '20250605_185846'
  },
];
