export async function api(path,method='GET',body){
 const token=sessionStorage.getItem('vantai_token');
 const response=await fetch('/api'+path,{method,headers:{...(token?{Authorization:`Bearer ${token}`}:{}) ,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
 const result=await response.json().catch(()=>({}));
 if(!response.ok){if(response.status===401&&path!=='/login'){sessionStorage.removeItem('vantai_token');window.dispatchEvent(new Event('auth-expired'))}throw new Error(result.error||`Lỗi HTTP ${response.status}`)}
 return result;
}
