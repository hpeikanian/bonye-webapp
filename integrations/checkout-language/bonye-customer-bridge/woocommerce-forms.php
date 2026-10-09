<?php
if(!defined('ABSPATH'))exit;
function bywp_unified_forms():bool{$c=bywp_config();return $c['enabled']&&$c['unified_forms'];}
add_action('template_redirect',function(){if(!bywp_unified_forms()||isset($_GET['bonye_login'])||isset($_POST['bonye_bridge'])||isset($_GET['bonye_legacy'])||wp_doing_ajax()||is_admin())return;if(is_checkout()&&!is_wc_endpoint_url('order-received')&&!current_user_can('manage_options')&&(!is_user_logged_in()||get_user_meta(get_current_user_id(),'_bonye_counterparty',true)==='')){nocache_headers();wp_safe_redirect(home_url('/?bonye_login=1'));exit;}if(is_account_page()&&!is_user_logged_in()){nocache_headers();wp_safe_redirect(home_url('/?bonye_login=1'));exit;}},1);
add_filter('woocommerce_registration_errors',function($errors){if(bywp_unified_forms())$errors->add('bonye_registration_required',bywp_admin_label('ثبت‌نام از مسیر ورود یکپارچه بنیه انجام شود.','Register through bonYe unified login.'));return $errors;});
add_filter('woocommerce_checkout_registration_enabled',function($enabled){return bywp_unified_forms()?false:$enabled;});
add_filter('option_woocommerce_enable_guest_checkout',function($value){return bywp_unified_forms()?'no':$value;});
add_filter('registration_errors',function($errors){if(bywp_unified_forms()&&!current_user_can('create_users'))$errors->add('bonye_registration_required',bywp_admin_label('برای ثبت‌نام مشتری از ورود یکپارچه بنیه استفاده کنید.','Use bonYe unified customer registration.'));return $errors;});
