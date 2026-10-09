<?php
if(!defined('ABSPATH'))exit;
function bywp_profile_identity(int $id):array{
 $u=get_user_by('id',$id);$cp=(int)get_user_meta($id,'_bonye_counterparty',true);$phone=(string)get_user_meta($id,'_bonye_mobile_verified',true);if(!bywp_eligible($u)||!$cp||!bywp_mobile($phone))throw new RuntimeException('identity_conflict');return ['action'=>'profile','counterparty_id'=>$cp,'user_id'=>$id,'mobile'=>$phone];
}
function bywp_profile_local(int $id):array{
 $u=get_user_by('id',$id);$full=trim((string)get_user_meta($id,'first_name',true).' '.(string)get_user_meta($id,'last_name',true));$d=['profile'=>['name'=>$full!==''?$full:(string)($u->display_name??''),'email'=>(string)($u->user_email??'')]];foreach(['billing','shipping'] as $kind){$d[$kind]=[];foreach(['first_name','last_name','company','address_1','address_2','city','state','postcode','country','phone'] as $field)$d[$kind][$field]=(string)get_user_meta($id,$kind.'_'.$field,true);}return $d;
}
function bywp_profile_write(int $id,array $view):void{
 $GLOBALS['bywp_profile_writing']=true;try{$d=$view['document'];$u=get_user_by('id',$id);$args=['ID'=>$id,'display_name'=>$d['profile']['name']];$email=$d['profile']['email'];$owner=$email!==''?email_exists($email):false;if($owner&&(int)$owner!==$id)throw new RuntimeException('email_conflict');$args['user_email']=$email;$r=wp_update_user($args);if(is_wp_error($r))throw new RuntimeException('website_profile_failed');
 $parts=explode(' ',trim($d['profile']['name']),2);update_user_meta($id,'first_name',$parts[0]??'');update_user_meta($id,'last_name',$parts[1]??'');
 foreach(['billing','shipping'] as $kind)foreach($d[$kind] as $field=>$value)update_user_meta($id,$kind.'_'.$field,$value);
 update_user_meta($id,'billing_phone',$d['profile']['mobile']);
 if(function_exists('WC')&&WC()->customer&&(int)WC()->customer->get_id()===$id){$customer=WC()->customer;$customer->set_display_name($d['profile']['name']);$customer->set_email($email);$customer->set_first_name($parts[0]??'');$customer->set_last_name($parts[1]??'');foreach(['billing','shipping'] as $kind)foreach($d[$kind] as $field=>$value){$setter='set_'.$kind.'_'.$field;if(method_exists($customer,$setter))$customer->$setter($value);}$customer->set_billing_phone($d['profile']['mobile']);$customer->save();}
 update_user_meta($id,'_bonye_profile_snapshot',bywp_profile_local($id));update_user_meta($id,'_bonye_profile_revision',$view['revision']);delete_user_meta($id,'_bonye_profile_pending');delete_user_meta($id,'_bonye_profile_status');
 }finally{$GLOBALS['bywp_profile_writing']=false;}
}
function bywp_profile_sync(int $id,bool $save=false):void{
 if(!bywp_config()['enabled']||!bywp_config()['profile_sync']||!empty($GLOBALS['bywp_profile_writing']))return;
 try{$base=bywp_profile_identity($id);$local=bywp_profile_local($id);$snapshot=get_user_meta($id,'_bonye_profile_snapshot',true);$revision=(string)get_user_meta($id,'_bonye_profile_revision',true);$pending=get_user_meta($id,'_bonye_profile_pending',true);
 if($save&&is_array($snapshot)&&$revision){$changes=[];foreach($local as $k=>$v)if($v!==($snapshot[$k]??null))$changes[$k]=$v;if($changes){$pending=['document'=>$changes,'revision'=>$revision];update_user_meta($id,'_bonye_profile_pending',$pending);}}
 if(is_array($pending)&&!empty($pending['document'])){$view=bywp_call($base+$pending);}
 else{$view=bywp_call($base);if(!isset($view['document']['profile'],$view['document']['billing'],$view['document']['shipping'],$view['revision']))throw new RuntimeException('profile_response_invalid');if(!$snapshot){$fill=[];foreach(['billing','shipping'] as $k)if(!array_filter($view['document'][$k])&&array_filter($local[$k]))$fill[$k]=$local[$k];$profile=[];foreach(['name','email'] as $f)if($view['document']['profile'][$f]===''&&$local['profile'][$f]!=='')$profile[$f]=$local['profile'][$f];if($profile)$fill['profile']=$profile;if($fill)$view=bywp_call($base+['document'=>$fill,'revision'=>$view['revision']]);}}
 if(!isset($view['document'],$view['revision']))throw new RuntimeException('profile_response_invalid');bywp_profile_write($id,$view);
 }catch(Throwable $e){$code=preg_match('/^[a-z_]{1,80}$/D',$e->getMessage())?$e->getMessage():'profile_sync_failed';update_user_meta($id,'_bonye_profile_status',$code);if(!in_array($code,['profile_conflict','email_conflict','identity_conflict'],true)&&!wp_next_scheduled('bonye_profile_retry',[$id]))wp_schedule_single_event(time()+60,'bonye_profile_retry',[$id]);}
}
add_action('bonye_profile_retry',function($id){bywp_profile_sync((int)$id);});
add_action('woocommerce_customer_save_address',function($id){bywp_profile_sync((int)$id,true);},20,1);
add_action('woocommerce_save_account_details',function($id){bywp_profile_sync((int)$id,true);},20,1);
add_action('woocommerce_checkout_order_processed',function($orderId,$posted,$order){$id=(int)$order->get_customer_id();if($id)bywp_profile_sync($id,true);},20,3);
add_action('template_redirect',function(){if(!bywp_config()['enabled']||!get_current_user_id()||(!is_account_page()&&!is_checkout()))return;$id=get_current_user_id();if(!get_user_meta($id,'_bonye_counterparty',true))return;bywp_profile_sync($id);$status=get_user_meta($id,'_bonye_profile_status',true);if($status)wc_add_notice(bywp_admin_label($status==='profile_conflict'?'اطلاعات هم‌زمان در بنیه تغییر کرده است. برای تطبیق آدرس‌ها با پشتیبانی تماس بگیرید؛ تغییر شما حفظ شده است.':'همگام‌سازی اطلاعات فعلاً انجام نشد؛ تغییر شما حفظ شده و دوباره تلاش می‌شود.',$status==='profile_conflict'?'Profile changed centrally at the same time. Contact support to reconcile; your edit is retained.':'Profile sync is temporarily unavailable. Your edit is retained for retry.'),'notice');},5);

add_action('woocommerce_update_customer',function($id){if(get_user_meta((int)$id,'_bonye_counterparty',true))bywp_profile_sync((int)$id,true);},20,1);
add_action('woocommerce_store_api_checkout_order_processed',function($order){$id=(int)$order->get_customer_id();if($id)bywp_profile_sync($id,true);},20,1);
/** Explicit conflict resolution belongs to the currently logged in customer, protected by WP nonce. */
add_action('template_redirect',function(){
 if(!isset($_POST['bonye_profile_resolve'])||!bywp_config()['enabled']||!bywp_config()['profile_sync'])return;$id=get_current_user_id();if(!$id)return;
 if(!wp_verify_nonce((string)($_POST['_wpnonce']??''),'bonye_profile_resolve'))wp_die(bywp_admin_label('درخواست معتبر نیست.','Invalid request.'));
 try{$base=bywp_profile_identity($id);$view=bywp_call($base);$choice=(string)$_POST['bonye_profile_resolve'];if($choice==='website'){$pending=get_user_meta($id,'_bonye_profile_pending',true);if(!is_array($pending)||empty($pending['document']))throw new RuntimeException('no_pending_profile');$view=bywp_call($base+['document'=>$pending['document'],'revision'=>$view['revision']]);}elseif($choice!=='central')throw new RuntimeException('invalid_action');bywp_profile_write($id,$view);wc_add_notice(bywp_admin_label('اطلاعات و آدرس‌ها تطبیق داده شد.','Profile and addresses reconciled.'),'success');}catch(Throwable $e){wc_add_notice(bywp_admin_label('تطبیق انجام نشد؛ دوباره تلاش کنید.','Reconciliation failed; try again.'),'error');}
 wp_safe_redirect(wc_get_account_endpoint_url('dashboard'));exit;
},1);
add_action('woocommerce_account_dashboard',function(){
 $id=get_current_user_id();if(!$id||get_user_meta($id,'_bonye_profile_status',true)!=='profile_conflict')return;
 ?><section><h3><?=esc_html(bywp_admin_label('تطبیق تغییرات اطلاعات','Reconcile profile changes'))?></h3><p><?=esc_html(bywp_admin_label('اطلاعات هم‌زمان تغییر کرده است. انتخاب «بنیه» تغییر ذخیره‌نشده سایت را کنار می‌گذارد؛ انتخاب «سایت» همان بخش‌های ویرایش‌شده را در بنیه جایگزین می‌کند.','Both sides changed. Choosing central discards the pending website edit; choosing website replaces those edited sections centrally.'))?></p><form method="post"><?php wp_nonce_field('bonye_profile_resolve');?><button name="bonye_profile_resolve" value="central"><?=esc_html(bywp_admin_label('استفاده از اطلاعات بنیه','Use central information'))?></button> <button name="bonye_profile_resolve" value="website"><?=esc_html(bywp_admin_label('ثبت تغییرات سایت در بنیه','Save website changes centrally'))?></button></form></section><?php
},5);
