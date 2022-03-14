require 'json'
require 'nokogiri'
require 'open-uri'

def rebuild_index(model)
  @index_present_prior =  model.__elasticsearch__.index_exists?
  index = model.rebuild_index! unless @index_present_prior
  @index_name = index[:index_name] unless index.nil?
end

def remove_index(model)
  model.delete_elasticsearch_index(@index_name) unless @index_present_prior
end

def generate_params(condition = nil, filter = "0")
  params = {
    utf8: '✓',
    search_mode: 'basic',
    filter: filter,
    cond_op: 'all',
    group_op: 'any',
    basic_search_mode: 'restricted',
    key: 'RequisitionHeadersController:requisition_header',
    as_json: true
  }
  unless condition.nil?
    params['conditions'] = {"#{SecureRandom.random_number(100000)}" => condition }
    params['search_mode'] = 'advanced'
  end

  params
end

def search_with_elastic_search(data_table, failover = true)
  failover_status = Setup.es_disable_failover?
  Setup.assign(:es_requisition_headers_requisition_header, true)
  Setup.assign(:es_disable_failover, true) unless failover
  ids = fetch_record_ids data_table
  Setup.assign(:es_disable_failover, failover_status)
  ids
end

def search_with_db(data_table)
  Setup.assign(:es_requisition_headers_requisition_header, false)
  fetch_record_ids data_table
end

def fetch_record_ids data_table
  url = "/requisition_headers/search_#{data_table}_table"
  params = generate_params
  @app.post(url, params: params, xhr: true)
  results = JSON.parse(@app.response.body)['rows']
  results.map {|result| result['id_num']}
end

def item_search(search_term, use_db = false)
  rebuild_index Item
  rebuild_index Supplier
  Setup.assign(:enable_elasticsearch, false) if use_db
  url = "/search/global_search"
  params = { browse_comm: '', scope_by: '', need: search_term, federated_search: 'true' , as_json: true}
  @app.post url, params: params, xhr: true
  html = @app.response.body.gsub(/\\+/, "")
  results = Nokogiri::HTML(html).css('body').css('input[type="checkbox"]')
  ids = fetch_item_ids results
  Setup.assign(:enable_elasticsearch, true)
  ids
end

def fetch_item_ids(results)
  results.map do |result|
    result['data-supplier-item-id'].to_i
  end
end


ApplicationController.class_eval do
  def set_current_user
    User.current_user = User.first
    User.current_user
  end
end


def override_protect_from_forgery
  override_method2 = <<-EOF
          protect_from_forgery unless: -> { User.current_user == User.first }
  EOF
  ApplicationController.instance_eval(override_method2)
end

@app = ActionDispatch::Integration::Session.new Rails.application
@app.host = "www.example.com"

override_protect_from_forgery


##################################################
data_table = 'requisition_header'
rebuild_index RequisitionHeader
es_records =  search_with_elastic_search data_table, false
db_records = search_with_db data_table

puts "es_records = #{es_records}"
puts "db_records = #{db_records}"

if es_records == db_records
  puts "datatable search TEST PASSED"
else
  puts "datatable search TEST FAILED"
end

remove_index RequisitionHeader


def home_page_item_search search_term, expected_search_results
  item_ids = item_search search_term
  puts "item_ids #{item_ids}"
  test_passed = true

  expected_search_results.each do |result|
    test_passed = false unless item_ids.index(result)
  end
  test_passed
end

result  = home_page_item_search('item', [1948, 1951, 1952, 1953]) ? "Home page search PASSED" : "home page search FAILED"

puts result


rebuild_index Item
rebuild_index Supplier
