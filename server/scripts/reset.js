import fs from 'node:fs'; import path from 'node:path'; import {fileURLToPath} from 'node:url';
const folder=path.join(path.dirname(fileURLToPath(import.meta.url)),'../data');
fs.rmSync(path.join(folder,'local.json'),{force:true});console.log('Đã xóa JSON local; lần chạy sau sẽ tạo lại dữ liệu demo.');
