<script setup>
import {computed} from 'vue';
const p=defineProps({modelValue:{type:Object,required:true},fields:{type:Array,required:true}});const emit=defineEmits(['update:modelValue','reset']);
function set(key,value){emit('update:modelValue',{...p.modelValue,[key]:value})}
</script><template><div class="filterbar"><label v-for="f in fields" :key="f.key"><span>{{f.label}}</span><select v-if="f.options" :value="modelValue[f.key]||''" @change="set(f.key,$event.target.value)"><option value="">Tất cả</option><option v-for="opt in f.options" :key="opt.value" :value="opt.value">{{opt.label}}</option></select><input v-else :type="f.type||'text'" :value="modelValue[f.key]||''" :placeholder="f.placeholder||''" @input="set(f.key,$event.target.value)"/></label><button class="secondary" @click="emit('reset')">Xóa lọc</button></div></template>
