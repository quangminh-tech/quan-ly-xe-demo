import {Router} from 'express';
import {buildReport} from '../services/report.service.js';
export function reportsRouter({database,auth}){
 const router=Router();router.use(auth);
 router.get('/',(req,res)=>{if(!['admin','accountant','director'].includes(req.user.role))return res.status(403).json({error:'Không đủ quyền xem báo cáo kế toán'});try{res.json(buildReport(database(),req.query,req.user))}catch(e){res.status(400).json({error:e.message})}});
 return router;
}
