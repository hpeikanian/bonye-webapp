<?php
if(!defined('ABSPATH'))exit;
// The app's explicit presentation language is scoped to this checkout request.
function bywp_checkout_language():string{
 $raw=$_POST['bonye_lang']??$_GET['bonye_lang']??null;
 if(is_string($raw)&&in_array($raw,['fa','en'],true))return $raw;
 return str_starts_with(get_locale(),'fa')?'fa':'en';
}
function bywp_checkout_enabled():bool{$c=bywp_config();return $c['enabled']&&$c['checkout_enabled']&&class_exists('WooCommerce')&&is_ssl();}
function bywp_checkout_capabilities():array{
 return bywp_call(['action'=>'checkout_capabilities','enabled'=>bywp_checkout_enabled(),'contract'=>'0.2.1','origin'=>strtolower((string)wp_parse_url(home_url('/'),PHP_URL_SCHEME)).'://'.strtolower((string)wp_parse_url(home_url('/'),PHP_URL_HOST)),'currency'=>get_woocommerce_currency()],true);
}
add_filter('cron_schedules',function($s){$s['bonye_four_minutes']=['interval'=>240,'display'=>'bonYe checkout capability heartbeat'];return $s;});
add_action('init',function(){if(bywp_config()['enabled']&&class_exists('WooCommerce')&&!wp_next_scheduled('bonye_checkout_capabilities'))wp_schedule_event(time()+1,'bonye_four_minutes','bonye_checkout_capabilities');});
add_action('bonye_checkout_capabilities',function(){try{bywp_checkout_capabilities();}catch(Throwable $e){/* Safe diagnostics already retained by transport. */}});
function bywp_checkout_customer(array $claim):object{
 $id=(int)($claim['user_id']??0);$u=get_user_by('id',$id);if(!bywp_eligible($u)||(get_current_user_id()&&get_current_user_id()!==$id)||(int)get_user_meta($id,'_bonye_counterparty',true)!==(int)$claim['counterparty_id']||bywp_mobile((string)get_user_meta($id,'_bonye_mobile_verified',true))!==bywp_mobile($claim['mobile']))throw new RuntimeException('identity_conflict');return $u;
}
function bywp_checkout_product(array $claim):array{
 $pid=(int)$claim['product_id'];$wid=(int)$claim['variation_id'];$qty=(int)$claim['quantity'];$parent=wc_get_product($pid);$product=$wid?wc_get_product($wid):$parent;
 if(!$parent||!$product||$parent->get_status()!=='publish'||$product->get_status()!=='publish'||($wid?(!$product->is_type('variation')||$product->get_parent_id()!==$pid):!$product->is_type('simple'))||!$product->is_purchasable()||!$product->is_in_stock())throw new RuntimeException('product_unavailable');
 $min=max(1,(int)apply_filters('woocommerce_quantity_input_min',$product->get_min_purchase_quantity(),$product));$max=(int)apply_filters('woocommerce_quantity_input_max',$product->get_max_purchase_quantity(),$product);$already=0;foreach(WC()->cart->get_cart() as $line)if((int)$line['product_id']===$pid&&(int)($line['variation_id']??0)===$wid)$already+=(int)$line['quantity'];
 if($qty<$min||$max>0&&$qty+$already>$max||!$product->has_enough_stock($qty+$already))throw new RuntimeException('quantity_limit');return ['product'=>$product,'attributes'=>$wid?$product->get_variation_attributes():[]];
}
function bywp_checkout_confirm(array $claim,string $browser):void{
 $u=bywp_checkout_customer($claim);$selection=bywp_checkout_product($claim);
 // Consume only after explicit confirmation; the current cart is never emptied/replaced.
 bywp_call(['action'=>'checkout_consume','grant_id'=>$claim['grant_id'],'browser_hash'=>$browser,'current_user_id'=>get_current_user_id()]);
 if(!get_current_user_id()){wc_set_customer_auth_cookie($u->ID);WC()->customer=new WC_Customer($u->ID,true);do_action('wp_login',$u->user_login,$u);}
 $data=['bonye_checkout'=>['grant_id'=>$claim['grant_id'],'counterparty_id'=>(int)$claim['counterparty_id'],'user_id'=>(int)$claim['user_id']]];
 $key=WC()->cart->add_to_cart((int)$claim['product_id'],(int)$claim['quantity'],(int)$claim['variation_id'],$selection['attributes'],$data);if(!$key)throw new RuntimeException('cart_add_failed');
 WC()->cart->calculate_totals();WC()->cart->set_session();
}
function bywp_checkout_begin():void{
 if(!isset($_GET['bonye_checkout'])&&!isset($_POST['bonye_checkout_stage']))return;
 $checkoutLanguage=bywp_checkout_language();
 add_filter('locale',static fn($locale)=>$checkoutLanguage==='fa'?'fa_IR':'en_US');
 if(!bywp_checkout_enabled())wp_die(bywp_admin_label('خرید فوری اپ در سایت غیرفعال است.','App checkout is disabled on this website.'));
 if(!defined('DONOTCACHEPAGE'))define('DONOTCACHEPAGE',true);nocache_headers();header('Referrer-Policy: no-referrer');header("Content-Security-Policy: frame-ancestors 'self'");
 if(!WC()->cart)wc_load_cart();$csrf=(string)($_COOKIE['bonye_checkout_csrf']??'');if(!preg_match('/^[a-f0-9]{64}$/D',$csrf)){$csrf=bin2hex(random_bytes(32));setcookie('bonye_checkout_csrf',$csrf,['expires'=>time()+600,'path'=>'/','secure'=>true,'httponly'=>true,'samesite'=>'Strict']);}
 $browser=hash('sha256',$csrf);$claim=get_transient('bywp_checkout_'.$browser)?:null;$message='';
 if(($_SERVER['REQUEST_METHOD']??'GET')==='POST'){
  if(!isset($_COOKIE['bonye_checkout_csrf'])||!hash_equals($csrf,(string)($_POST['csrf']??'')))wp_die(bywp_admin_label('درخواست معتبر نیست.','Invalid request.'));
  try{$stage=(string)($_POST['bonye_checkout_stage']??'');if($stage==='claim'){$ticket=(string)wp_unslash($_POST['ticket']??'');if(!preg_match('/^[a-f0-9]{64}$/D',$ticket))throw new RuntimeException('invalid_checkout_link');$claim=bywp_call(['action'=>'checkout_claim','ticket'=>$ticket,'browser_hash'=>$browser,'current_user_id'=>get_current_user_id()]);bywp_checkout_customer($claim);bywp_checkout_product($claim);set_transient('bywp_checkout_'.$browser,$claim,300);}
   elseif($stage==='confirm'){if(!$claim)throw new RuntimeException('checkout_link_expired');bywp_checkout_confirm($claim,$browser);delete_transient('bywp_checkout_'.$browser);wp_safe_redirect(wc_get_checkout_url());exit;}
   elseif($stage==='cancel'){delete_transient('bywp_checkout_'.$browser);wp_safe_redirect(home_url('/'));exit;}else throw new RuntimeException('invalid_action');
  }catch(Throwable $e){$message=bywp_error_message($e);$claim=null;delete_transient('bywp_checkout_'.$browser);}
 }
 header('Content-Type: text/html; charset=utf-8');require __DIR__.'/app-checkout-view.php';exit;
}
add_action('template_redirect','bywp_checkout_begin',0);
add_action('woocommerce_checkout_create_order_line_item',function($item,$key,$values,$order){if(!empty($values['bonye_checkout'])){$ctx=$values['bonye_checkout'];$item->add_meta_data('_bonye_checkout_grant',(string)$ctx['grant_id'],true);$item->add_meta_data('_bonye_counterparty',(int)$ctx['counterparty_id'],true);}},10,4);
function bywp_tag_order($order):void{
 if(!bywp_config()['enabled']||!$order||!$order->get_id())return;$id=(int)$order->get_id();$uid=(int)$order->get_customer_id();$context=null;
 foreach($order->get_items() as $item){$grant=(string)$item->get_meta('_bonye_checkout_grant');$cp=(int)$item->get_meta('_bonye_counterparty');if(preg_match('/^[a-f0-9]{32}$/D',$grant)&&$cp){$context=['grant_id'=>$grant,'counterparty_id'=>$cp];break;}}
 if(!$context&&WC()->cart){foreach(WC()->cart->get_cart() as $line){$ctx=$line['bonye_checkout']??null;if(!$ctx||(int)$ctx['user_id']!==$uid)continue;foreach($order->get_items() as $item)if((int)$item->get_product_id()===(int)$line['product_id']&&(int)$item->get_variation_id()===(int)($line['variation_id']??0)){$context=['grant_id'=>$ctx['grant_id'],'counterparty_id'=>(int)$ctx['counterparty_id']];$item->add_meta_data('_bonye_checkout_grant',$ctx['grant_id'],true);$item->add_meta_data('_bonye_counterparty',$ctx['counterparty_id'],true);$item->save();break 2;}}}
 try{
  if($context){if((int)get_user_meta($uid,'_bonye_counterparty',true)!==$context['counterparty_id'])throw new RuntimeException('identity_conflict');$r=bywp_call(['action'=>'checkout_order','grant_id'=>$context['grant_id'],'counterparty_id'=>$context['counterparty_id'],'user_id'=>$uid,'order_id'=>$id]);$order->update_meta_data('_bonye_purchase_origin','app');$order->update_meta_data('_bonye_checkout_grant',$context['grant_id']);$order->update_meta_data('_bonye_origin_proof',$r['proof']);}
  else{$key=bywp_config()['secret'];if(!preg_match('/^[a-f0-9]{64}$/D',$key))return;$order->update_meta_data('_bonye_purchase_origin','website');$order->update_meta_data('_bonye_origin_proof',hash_hmac('sha256',"bonye/website-origin/v1\n$id\n$uid",$key));}
  $order->save_meta_data();if($context)bywp_call(['action'=>'checkout_notify','grant_id'=>$context['grant_id'],'order_id'=>$id]);$order->delete_meta_data('_bonye_origin_attempt');$order->save_meta_data();
 }catch(Throwable $e){$attempt=(int)$order->get_meta('_bonye_origin_attempt');$order->update_meta_data('_bonye_origin_attempt',$attempt+1);$order->save_meta_data();if($attempt<8&&!wp_next_scheduled('bonye_order_origin_retry',[$id]))wp_schedule_single_event(time()+min(3600,30*(2**$attempt)),'bonye_order_origin_retry',[$id]);}
}
add_action('woocommerce_checkout_order_created','bywp_tag_order',20,1);
add_action('woocommerce_store_api_checkout_order_processed','bywp_tag_order',20,1);
add_action('bonye_order_origin_retry',function($id){bywp_tag_order(wc_get_order((int)$id));});
function bywp_validate_app_cart($cart):void{
 $cp=0;$lines=[];foreach($cart->get_cart() as $line){$ctx=$line['bonye_checkout']??null;if($ctx){if($cp&&$cp!==(int)$ctx['counterparty_id'])throw new RuntimeException('identity_conflict');$cp=(int)$ctx['counterparty_id'];if((int)$ctx['user_id']!==get_current_user_id())throw new RuntimeException('identity_conflict');}$lines[]=['product_id'=>(int)$line['product_id'],'variation_id'=>(int)($line['variation_id']??0),'quantity'=>(int)$line['quantity'],'grant_id'=>$ctx['grant_id']??null];}
 if($cp)bywp_call(['action'=>'checkout_cart','counterparty_id'=>$cp,'user_id'=>get_current_user_id(),'lines'=>$lines]);
}
add_action('woocommerce_check_cart_items',function(){if(!WC()->cart)return;try{bywp_validate_app_cart(WC()->cart);}catch(Throwable $e){wc_add_notice(bywp_error_message($e),'error');}});
add_action('woocommerce_store_api_cart_errors',function($errors,$cart){try{bywp_validate_app_cart($cart);}catch(Throwable $e){$errors->add('bonye_checkout_unavailable',bywp_error_message($e));}},20,2);
