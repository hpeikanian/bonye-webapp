<?php
// Isolated WordPress stubs: no remote calls, account changes or cart writes.
define('ABSPATH', __DIR__);
$filters=[];
function add_filter($name,$callback,$priority=10,$args=1){global $filters;$filters[$name][]=$callback;}
function add_action(...$args){}
function get_locale(){global $filters;$value='en_US';foreach($filters['locale']??[] as $callback)$value=$callback($value);return $value;}
function bywp_admin_label($fa,$en){return str_starts_with(get_locale(),'fa')?$fa:$en;}
function bywp_config(){return ['enabled'=>true,'checkout_enabled'=>true];}
class WooCommerce{}
function is_ssl(){return true;}
function nocache_headers(){}
class Cart{function get_cart(){return [];}}
function WC(){static $wc;$wc??=(object)['cart'=>new Cart];return $wc;}
function esc_html($v){return htmlspecialchars($v,ENT_QUOTES,'UTF-8');}
function esc_attr($v){return esc_html($v);}
function apply_filters($name,$value,...$args){return $value;}
class Product{
 function get_status(){return 'publish';} function is_type($type){return $type==='simple';}
 function is_purchasable(){return true;}function is_in_stock(){return true;}
 function get_min_purchase_quantity(){return 1;}function get_max_purchase_quantity(){return 10;}
 function has_enough_stock($qty){return $qty<=10;}function get_name(){return 'Sample product';}
}
function wc_get_product($id){return new Product;}
function get_transient($key){return ($GLOBALS['argv'][2]??'')==='claim'?
 ['product_id'=>20,'variation_id'=>0,'quantity'=>2,'name'=>'Example','mobile'=>'09000000000']:null;}
$_GET=['bonye_checkout'=>'1','bonye_lang'=>$argv[1]??'en'];
$_COOKIE=['bonye_checkout_csrf'=>str_repeat('a',64)];
$_SERVER['REQUEST_METHOD']='GET';
require __DIR__.'/../bonye-customer-bridge/app-checkout.php';
bywp_checkout_begin();
