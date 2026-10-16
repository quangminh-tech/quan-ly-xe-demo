<script setup>
defineProps({label:String,value:[String,Number],sub:String,icon:Object});
</script>
<template><div class="stat"><div class="stat-icon"><component :is="icon" :size="20"/></div><div class="stat-number">{{value}}</div><div class="stat-caption">{{label}}</div><div v-if="sub" class="stat-sub">{{sub}}</div></div></template>
