import './styles.css';
import { start } from './app.js';
import seed from '../resources/seed-ontologia.json';
import type { SeedFile } from './core/storage.js';

const mount = document.getElementById('app');
if (mount) void start(mount, seed as unknown as SeedFile);
