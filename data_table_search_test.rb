require 'faraday'
require 'json'

def rebuild_index(model)
  @index_present_prior =  model.__elasticsearch__.index_exists?
  index = model.rebuild_index!
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
  # matches = @app.response.body.match(/\$.+##{data_table}_tbody.+.append.+(<tr.+)\);/)
  # rows = Nokogiri::HTML(matches[0].gsub(/\\+/, "")).css('tr.coupa_datatable_row')
  # rows.map do  |row|
  #   /[0-9]+/.match(row.css('td')[0].css('a').first.to_s).to_s
  # end
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
data_table = 'requisition_header'
rebuild_index RequisitionHeader
es_records =  search_with_elastic_search data_table, false
db_records = search_with_db data_table

puts "es_records = #{es_records}"
puts "db_records = #{db_records}"

if es_records == db_records
  puts "TEST PASSED"
else
  puts "TEST FAILED"
end

remove_index RequisitionHeader
