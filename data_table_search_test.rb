user =  User.where(login: "karun.rajagopal@coupa.com").first
User.current_user = user
record = 'requisition_headers'
data_table = 'requisition_header'
controller =  RequisitionHeadersController

adv_search_condition = { "col_key" => "created_by", "created_by_op" => "contains_keywords", "created_by" => "#{user.firstname}", "created_by_id" => "#{user.id}", "del" => "" }
params = generate_params adv_search_condition


search_data_table controller,data_table,params

def generate_params(condition = nil, filter = "0")
  params = {
    "utf8" => "✓",
    "search_mode" => "basic",
    "filter" => filter,
    "cond_op" => "all",
    "group_op" => "any",
    "basic_search_mode" => "restricted",
    "key" => "RequisitionHeadersController:requisition_header"
  }
  unless condition.nil?
   params['conditions'] = {"#{SecureRandom.random_number(100000)}" => condition }
   params['search_mode'] = 'advanced'
  end

  params
end

def search_data_table controller,data_table,params
  post "/#{controller}/search_#{data_table}_table", params: params, xhr: true
end

def post(path, params = nil, headers = {})
  header_options = headers.empty? ? json_headers : headers
  Coupa::Service.request(:post, build_url(hostname, path, control_url_details), header_options, params)
end

def control_url
  @control_url ||= URI.parse(SimpleConfig.for(:application).control_url)
end

def json_headers
  {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
end

def hostname
  control_url.host
end

def control_url_details
  {
    scheme: control_url.scheme,
    port: control_url.port
  }
end

def build_url(hostname, path, options = {})
  uri_options = {
    host: hostname,
    path: (path.start_with?('/') ? path : "/#{path}")
  }
  uri_options[:query] = options[:params].to_query if options[:params].present?
  uri_options[:port]  = options[:port] if options[:port].present?
  uri_class = options[:scheme] == 'http' ? URI::HTTP : URI::HTTPS
  uri_class.build(uri_options)
end


# SET GLOBAL sql_mode=‘STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION'
#
#
# | ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION |