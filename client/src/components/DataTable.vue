<script setup>
import {computed,ref,watch} from 'vue';
const p=defineProps({rows:{type:Array,default:()=>[]},columns:{type:Array,default:()=>[]},pageSize:{type:Number,default:12},formatter:Function});
const emit=defineEmits(['select']);const page=ref(1);const sort=ref(''),desc=ref(false);
const sorted=computed(()=>{if(!sort.value)return p.rows;return [...p.rows].sort((a,b)=>{const av=a[sort.value]??'',bv=b[sort.value]??'';return (typeof av==='number'&&typeof bv==='number'?av-bv:String(av).localeCompare(String(bv),'vi'))*(desc.value?-1:1)})});
const pages=computed(()=>Math.max(1,Math.ceil(sorted.value.length/p.pageSize)));
const displayed=computed(()=>sorted.value.slice((page.value-1)*p.pageSize,page.value*p.pageSize));
watch(()=>p.rows,()=>{page.value=1});
function order(key){if(sort.value===key)desc.value=!desc.value;else{sort.value=key;desc.value=false}}
function show(row,col){return p.formatter?p.formatter(row[col[0]],col[0]):row[col[0]]??'—'}
</script>
<template><div class="table-wrap"><table><thead><tr><th v-for="c in columns" :key="c[0]" @click="order(c[0])" class="sort-th">{{c[1]}} <span v-if="sort===c[0]">{{desc?'↓':'↑'}}</span></th><th v-if="$slots.actions">Thao tác</th></tr></thead><tbody><tr v-for="row in displayed" :key="row.id" @click="emit('select',row)"><td v-for="c in columns" :key="c[0]">{{show(row,c)}}</td><td v-if="$slots.actions" @click.stop><slot name="actions" :row="row"/></td></tr><tr v-if="!displayed.length"><td :colspan="columns.length+($slots.actions?1:0)"><div class="empty">Không có dữ liệu phù hợp bộ lọc</div></td></tr></tbody></table></div><div class="pagination"><span>Hiển thị {{displayed.length}} / {{rows.length}} bản ghi</span><div><button class="secondary" :disabled="page<=1" @click="page--">Trước</button><b>{{page}} / {{pages}}</b><button class="secondary" :disabled="page>=pages" @click="page++">Sau</button></div></div></template>
