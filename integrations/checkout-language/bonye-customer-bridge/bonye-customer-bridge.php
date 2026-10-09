<?php
/**
 * Plugin Name: bonYe Customer Bridge
 * Description: Verified central customer login/linking; no separate loyalty or customer store.
 * Version: 1.4.1
 * Requires PHP: 8.1
 */
if(!defined('ABSPATH'))exit;
function bywp_t(string $text):string{if(str_starts_with(get_locale(),'fa'))return $text;$map=['ادامه با حساب %s، شماره %s%s؟'=>'Continue as %s, phone %s%s?', ' و اتصال به حساب فعلی سایت'=>' and link to your current website account', 'ورود بنیه' => 'bonYe login', 'ورود با حساب بنیه' => 'Sign in with bonYe', 'کد پیامک' => 'SMS code', 'تأیید موبایل' => 'Verify mobile', 'شماره موبایل بنیه' => 'bonYe mobile number', 'دریافت کد ورود' => 'Send login code', 'تأیید و ادامه خرید' => 'Confirm and continue checkout', 'ادامه از اپ' => 'Continue from app', 'ورود با حساب قبلی سایت' => 'Sign in to an existing website account', 'ورود با موبایل بنیه' => 'Sign in with bonYe mobile', 'برای ادامه با حساب اپ، دکمه زیر را بزنید و هویت نمایش‌داده‌شده را تأیید کنید.' => 'Continue below and confirm the identity shown before signing in.', 'کد تأیید برای شماره واجد شرایط ارسال شد.' => 'A verification code was sent if this number is eligible.', 'این شماره در حسابی از سایت ثبت شده است. ابتدا با روش فعلی وارد همان حساب سایت شوید، سپس تأیید موبایل بنیه را دوباره انجام دهید.' => 'This phone is present on an existing website account. Sign in to that account first, then verify your bonYe mobile again.', 'اطلاعات حساب‌ها تعارض دارد؛ اتصال خودکار انجام نشد. پشتیبانی باید بررسی کند.' => 'Account identity conflict. No automatic merge was performed; contact support.', 'کد نامعتبر یا منقضی است؛ کد تازه درخواست کنید.' => 'Invalid or expired code; request a new one.', 'فرصت ورود پایان یافته؛ دوباره از اپ یا با پیامک وارد شوید.' => 'Login authorization expired; start again from the app or SMS login.', 'ورود انجام نشد؛ تنظیمات سرویس، فعال بودن ورود و اتصال را بررسی کنید.' => 'Login failed; check service configuration and whether login is enabled.', 'درخواست معتبر نیست.' => 'Invalid request.', 'HTTPS و WooCommerce فعال لازم است.' => 'HTTPS and active WooCommerce are required.'];return $map[$text]??$text;}
function bywp_config():array{
 $o=get_option('bonye_bridge_settings',[]);if(!is_array($o))$o=[];
 return ['checkout_enabled'=>!empty($o['checkout_enabled']),'profile_sync'=>array_key_exists('profile_sync',$o)?(bool)$o['profile_sync']:true,'enabled'=>array_key_exists('enabled',$o)?(bool)$o['enabled']:(defined('BONYE_BRIDGE_ENDPOINT')&&defined('BONYE_BRIDGE_SECRET')),'endpoint'=>$o['endpoint']??(defined('BONYE_BRIDGE_ENDPOINT')?BONYE_BRIDGE_ENDPOINT:''),'unified_forms'=>array_key_exists('unified_forms',$o)?(bool)$o['unified_forms']:false,'secret'=>$o['secret']??(defined('BONYE_BRIDGE_SECRET')?BONYE_BRIDGE_SECRET:'')];
}
function bywp_call(array $body,bool $test=false):array{
 $c=bywp_config();if(!$test&&!$c['enabled'])throw new RuntimeException('bridge_disabled');if(!preg_match('/^[a-f0-9]{64}$/D',$c['secret'])||parse_url($c['endpoint'],PHP_URL_SCHEME)!=='https')throw new RuntimeException('bridge_not_configured');
 $body['client_ip']=$_SERVER['REMOTE_ADDR']??'';$raw=wp_json_encode($body,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);$time=(string)time();$nonce=bin2hex(random_bytes(16));
 $r=wp_remote_post($c['endpoint'],['timeout'=>($body['action']??'')==='profile'?10:35,'redirection'=>0,'sslverify'=>true,'headers'=>['Content-Type'=>'application/json','X-Bonye-Time'=>$time,'X-Bonye-Nonce'=>$nonce,'X-Bonye-Signature'=>hash_hmac('sha256',$time."\n".$nonce."\n".hash('sha256',$raw),$c['secret'])],'body'=>$raw]);
 if(is_wp_error($r)){$GLOBALS['bywp_error_id']='';update_option('bonye_bridge_last_error',['code'=>'transport_error','status'=>0,'request_id'=>'','time'=>time(),'operation'=>$body['action']],false);throw new RuntimeException('transport_error');}
 $b=json_decode(wp_remote_retrieve_body($r),true);$status=wp_remote_retrieve_response_code($r);$id=(string)($b['meta']['request_id']??'');$GLOBALS['bywp_error_id']=preg_match('/^[a-f0-9]{24}$/D',$id)?$id:'';
 if($status!==200||!isset($b['data'])){$code=(string)($b['error']['code']??'bridge_unavailable');if(!preg_match('/^[a-z_]{1,80}$/D',$code))$code='bridge_unavailable';update_option('bonye_bridge_last_error',['code'=>$code,'status'=>$status,'request_id'=>$GLOBALS['bywp_error_id'],'time'=>time(),'operation'=>$body['action']],false);throw new RuntimeException($code);}return $b['data'];
}
function bywp_mobile(string $s):string{$s=strtr($s,array_combine(preg_split('//u','۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩',-1,PREG_SPLIT_NO_EMPTY),str_split('01234567890123456789')));$s=preg_replace('/[\s()+-]/u','',$s);if(str_starts_with($s,'0098'))$s='0'.substr($s,4);elseif(str_starts_with($s,'98'))$s='0'.substr($s,2);return preg_match('/^09[0-9]{9}$/D',$s)?$s:'';}
function bywp_eligible($u):bool{return $u&&array_intersect($u->roles,['customer','subscriber'])&&!array_diff($u->roles,['customer','subscriber'])&&!user_can($u,'manage_options')&&!user_can($u,'edit_posts');}
function bywp_account(array $claim):int{
 global $wpdb;$cp=(int)$claim['id'];$mapped=(int)$claim['woo_customer_id'];$current=get_current_user_id();$mobile=$claim['mobile'];
 if($mapped){$u=get_user_by('id',$mapped);if(!bywp_eligible($u)||($current&&$current!==$mapped))throw new RuntimeException('identity_conflict');if(((int)get_user_meta($mapped,'_bonye_counterparty',true)!==$cp||bywp_mobile((string)get_user_meta($mapped,'_bonye_mobile_verified',true))!==$mobile)&&$current!==$mapped)throw new RuntimeException('website_login_required');$id=$mapped;}
 elseif($current){$u=get_user_by('id',$current);if(!bywp_eligible($u))throw new RuntimeException('staff_account_forbidden');$id=$current;}
 else{
  $ids=get_users(['meta_key'=>'_bonye_counterparty','meta_value'=>(string)$cp,'fields'=>'ID','number'=>2]);if(count($ids)>1)throw new RuntimeException('identity_conflict');
  if($ids){$id=(int)$ids[0];if(!bywp_eligible(get_user_by('id',$id)))throw new RuntimeException('staff_account_forbidden');}
  else{
   // A billing phone is not proof of ownership: require existing WordPress login before linking.
   $rows=$wpdb->get_results("SELECT user_id,meta_value FROM {$wpdb->usermeta} WHERE meta_key IN ('billing_phone','mobile','phone_number','digits_phone_no','digits_phone')",ARRAY_A);
   foreach($rows as $row)if(bywp_mobile((string)$row['meta_value'])===$mobile)throw new RuntimeException('website_login_required');
   $login='bonye_'.$cp;if(username_exists($login))throw new RuntimeException('identity_conflict');
   $id=wp_insert_user(['user_login'=>$login,'user_pass'=>wp_generate_password(40,true,true),'display_name'=>sanitize_text_field($claim['name']),'role'=>'customer']);if(is_wp_error($id))throw new RuntimeException('website_account_failed');
   update_user_meta($id,'_bonye_counterparty',(string)$cp);
  }
 }
 $bound=get_user_meta($id,'_bonye_counterparty',true);if($bound!==''&&(int)$bound!==$cp)throw new RuntimeException('identity_conflict');
 bywp_call(['action'=>'bind','ticket'=>$claim['binding_ticket'],'user_id'=>(int)$id]);
 update_user_meta($id,'_bonye_counterparty',(string)$cp);update_user_meta($id,'_bonye_mobile_verified',$mobile);update_user_meta($id,'billing_phone',$mobile);bywp_profile_sync((int)$id);return (int)$id;
}
function bywp_error_message(Throwable $e):string{
 $messages=['checkout_link_expired'=>['لینک خرید منقضی است؛ از اپ لینک تازه درخواست کنید.','Checkout link expired; request a new one in the app.'],'checkout_link_used'=>['این لینک قبلاً مصرف شده است.','This checkout link has already been used.'],'checkout_browser_conflict'=>['این لینک در مرورگر دیگری باز شده است.','This link is bound to a different browser.'],'product_unavailable'=>['کالا در حال حاضر قابل خرید نیست.','This product is not currently purchasable.'],'quantity_limit'=>['تعداد از حد خرید یا موجودی عبور می‌کند.','Quantity exceeds the stock or purchase limit.'],'insufficient_stock'=>['موجودی کافی نیست.','Insufficient stock.'],'quick_buy_unavailable'=>['اتصال خرید فوری آماده نیست.','The quick-buy bridge is not ready.'],'invalid_credentials'=>['موبایل یا رمز بنیه درست نیست.','Incorrect bonYe mobile or password.'],'mobile_verification_required'=>['ابتدا با پیامک موبایل خود را تأیید کنید.','Verify your mobile using SMS first.'],'otp_required'=>['برای این حساب ورود با پیامک لازم است.','This account requires SMS verification.'],'recovery_required'=>['برای این حساب ابتدا بازیابی رمز را انجام دهید.','Use password recovery for this account first.'],'password_policy'=>['رمز باید بین ۱۲ تا ۷۲ بایت باشد.','Password must contain 12 to 72 bytes.'],'password_mismatch'=>['تکرار رمز یکسان نیست.','Passwords do not match.'],'invalid_challenge'=>['کد نادرست یا منقضی است؛ دوباره بررسی یا کد تازه درخواست کنید.','Invalid or expired code; check it or request a new one.'],'invalid_ticket'=>['فرصت ادامه ورود پایان یافته؛ دوباره وارد شوید.','Login authorization expired; start again.'],'website_login_required'=>['ابتدا وارد حساب قبلی سایت شوید و سپس موبایل بنیه را تأیید کنید.','Sign in to your existing website account, then verify your bonYe mobile.'],'identity_conflict'=>['حساب‌ها تعارض دارند؛ اتصال متوقف شد. با پشتیبانی تماس بگیرید.','Identity conflict; linking stopped. Contact support.'],'rate_limited'=>['تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.','Too many requests; try again later.'],'otp_cooldown'=>['برای درخواست کد تازه کمی صبر کنید.','Wait before requesting a new code.'],'transport_error'=>['پاسخ بنیه به موقع نرسید. اگر پیامک رسیده ولی فرم کد باز نشده، بعد از پایان مهلت ارسال دوباره تلاش کنید.','The central response did not arrive in time. If SMS arrived without a code form, retry after the resend cooldown.'],'auth_method_disabled'=>['این روش ورود در پنل بنیه خاموش است.','This login method is disabled centrally.'],'registration_disabled'=>['ثبت‌نام مشتری تازه در بنیه خاموش است.','New registration is disabled centrally.'],'recovery_disabled'=>['بازیابی حساب در بنیه خاموش است.','Recovery is disabled centrally.'],'sms_not_configured'=>['تنظیمات پیامک بنیه آماده نیست.','Central SMS is not configured.']];$m=$messages[$e->getMessage()]??['ورود انجام نشد. کد خطا را برای پشتیبانی ارسال کنید.','Login failed; share the error code with support.'];$code=preg_match('/^[a-z_]{1,80}$/D',$e->getMessage())?$e->getMessage():'website_login_failed';return bywp_admin_label($m[0],$m[1]).' ['.$code.']'.(!empty($GLOBALS['bywp_error_id'])?' #'.$GLOBALS['bywp_error_id']:'');
}
function bywp_begin():void{
 if(!isset($_GET['bonye_login'])&&!isset($_POST['bonye_bridge']))return;
 if(!bywp_config()['enabled'])wp_die(bywp_admin_label('ورود یکپارچه سایت غیرفعال است.','Unified website login is disabled.'));
 if(!defined('DONOTCACHEPAGE'))define('DONOTCACHEPAGE',true);nocache_headers();header('Referrer-Policy: no-referrer');header("Content-Security-Policy: frame-ancestors 'self'");
 if(!is_ssl()||!class_exists('WooCommerce'))wp_die(bywp_t('HTTPS و WooCommerce فعال لازم است.'));
 $csrf=$_COOKIE['bonye_bridge_csrf']??'';if(!preg_match('/^[a-f0-9]{64}$/D',$csrf)){$csrf=bin2hex(random_bytes(32));setcookie('bonye_bridge_csrf',$csrf,['expires'=>time()+900,'path'=>'/','secure'=>true,'httponly'=>true,'samesite'=>'Strict']);}
 $key=hash('sha256',$csrf);$flow=get_transient('bywp_flow_'.$key)?:[];$mode=(string)($_GET['mode']??'login');if(!in_array($mode,['login','register','recovery','password'],true))$mode='login';$message='';$claim=null;
 if(($_SERVER['REQUEST_METHOD']??'GET')==='GET'&&(isset($_GET['restart'])||(!empty($flow['mode'])&&$flow['mode']!==$mode))){delete_transient('bywp_flow_'.$key);$flow=[];}
 if(($_SERVER['REQUEST_METHOD']??'')==='POST'){
  if(!isset($_COOKIE['bonye_bridge_csrf'])||!hash_equals($csrf,(string)($_POST['csrf']??'')))wp_die(bywp_t('درخواست معتبر نیست.'));
  try{
   $stage=(string)($_POST['bonye_bridge']??'');
   if($stage==='request'){
    $mode=(string)($_POST['mode']??'login');if(!in_array($mode,['login','register','recovery'],true))throw new RuntimeException('invalid_action');
    $r=bywp_call(['action'=>'request','mobile'=>sanitize_text_field(wp_unslash($_POST['mobile']??'')),'mode'=>$mode]);$flow=['mode'=>$mode,'challenge'=>$r['challenge_id']];set_transient('bywp_flow_'.$key,$flow,600);$message=bywp_t('کد تأیید برای شماره واجد شرایط ارسال شد.');
   }elseif($stage==='verify'){
    if(empty($flow['challenge']))throw new RuntimeException('invalid_challenge');$mode=$flow['mode'];$body=['action'=>'verify','challenge_id'=>$flow['challenge'],'code'=>sanitize_text_field(wp_unslash($_POST['code']??''))];
    if(in_array($mode,['register','recovery'],true)){if(($_POST['new_password']??'')!==($_POST['password_repeat']??''))throw new RuntimeException('password_mismatch');$body['new_password']=(string)wp_unslash($_POST['new_password']??'');}
    if($mode==='register')$body['name']=sanitize_text_field(wp_unslash($_POST['name']??''));
    $claim=bywp_call($body);if(!empty($claim['registration_existing_account']))$message=bywp_admin_label('این حساب از قبل وجود داشت؛ رمز قبلی تغییر نکرد. برای رمز تازه از بازیابی استفاده کنید.','This account already existed; its password was not changed. Use recovery to set a new password.');delete_transient('bywp_flow_'.$key);$flow=[];
   }elseif($stage==='password'){$mode='password';$claim=bywp_call(['action'=>'password','mobile'=>sanitize_text_field(wp_unslash($_POST['mobile']??'')),'password'=>(string)wp_unslash($_POST['password']??'')]);}
   elseif($stage==='consume'){$claim=bywp_call(['action'=>'consume','ticket'=>sanitize_text_field(wp_unslash($_POST['ticket']??''))]);}
   elseif($stage==='confirm'){
    $claim=get_transient('bywp_claim_'.$key);if(!$claim)throw new RuntimeException('invalid_ticket');global $wpdb;$lock=hash('sha256','bonye/wp/'.get_current_blog_id());if((int)$wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s,3)',$lock))!==1)throw new RuntimeException('try_again');
    try{$id=bywp_account($claim);}finally{$wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)',$lock));}
    delete_transient('bywp_claim_'.$key);delete_transient('bywp_flow_'.$key);wp_set_current_user($id);wp_set_auth_cookie($id,false,true);wp_safe_redirect(wc_get_checkout_url());exit;
   }else throw new RuntimeException('invalid_action');
   if($claim)set_transient('bywp_claim_'.$key,$claim,60);
  }catch(Throwable $e){$message=bywp_error_message($e);$claim=null;}
 }
 header('Content-Type: text/html; charset=utf-8');require __DIR__.'/login-view.php';exit;
}
add_action('template_redirect','bywp_begin',0);
add_action('woocommerce_login_form_end',function(){if(!bywp_config()['enabled'])return;echo '<p><a href="'.esc_url(home_url('/?bonye_login=1')).'">'.esc_html(bywp_t('ورود با موبایل بنیه')).'</a></p>';});
require_once __DIR__.'/admin.php';
require_once __DIR__.'/woocommerce-forms.php';

require_once __DIR__.'/customer-area.php';

require_once __DIR__.'/profile-sync.php';

require_once __DIR__.'/app-checkout.php';
