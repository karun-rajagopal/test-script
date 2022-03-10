require 'faraday'
require 'json'
require 'nokogiri'
require 'open-uri'

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


# @records = seed_data

expected_search_results = [1 ,2]

puts "expected ids #{expected_search_results}"

def home_page_item_search expected_search_results
  item_ids = item_search 'coupa'
  # db_results = item_search 'coupa', true
  puts "item_ids #{item_ids}"
  test_passed = true

  expected_search_results.each do |result|
    test_passed = false unless item_ids.index(result)
  end
  test_passed
end

result  = home_page_item_search(expected_search_results) ? "Home page search PASSED" : "home page search FAILED"

puts result

# DatabaseCleaner.clean_with(:truncation)
# DatabaseCleaner.clean

rebuild_index Item
rebuild_index Supplier

# puts "SupplierItem count after script:  #{SupplierItem.count}"
#
#





# require 'factory_girl'
# require 'factory_girl_rails'
# require 'database_cleaner'

# Dir[Rails.root.join 'engines/suppliers/spec/factories/**.rb'].each { |file| require file }
#
# DatabaseCleaner.strategy = :transaction
#
# DatabaseCleaner.start # usually this is called in setup of a test
#
# puts "SupplierItem count before script: #{SupplierItem.count}"

#
# def create_supplier_item (item_name, supplier_name = nil)
#   supplier = supplier_name.nil? ? FactoryGirl.create(:supplier) : FactoryGirl.create(:supplier, name: supplier_name, number: supplier_name)
#   item = FactoryGirl.create(:item, name: item_name)
#   FactoryGirl.create(:supplier_item, supplier: supplier , item: item)
# end
#
# def seed_data
#   rebuild_index Item
#   [
#     create_supplier_item('coupa test item', "supplier1_#{Time.now.to_i}"),
#     create_supplier_item('dev coupa item', "supplier2_#{Time.now.to_i}"),
#     create_supplier_item('random item', "supplier3_#{Time.now.to_i}"),
#   ]
# end

# def rebuild_index(model = 'all')
#   if model == 'all'
#     Search::Searchable::INDEXED_MODELS.each do |record|
#     klass = record.constantize
#     klass.rebuild_index! unless klass.index_exists?
#     end
#   else
#     model.constantize.rebuild_index! unless model.index_exists?
#   end
# end