class GeneralReportsController < ReportsController


  def product
    render_report(0, 'Name') {|od| od.product.name }
  end


  def account
    render_report(1, 'Number') {|od| od.account.account_number }
  end


  def account_owner
    render_report(2, 'Name') do |od|
      owner=od.account.owner.user
      "#{owner.full_name} (#{owner.username})"
    end
  end


  def purchaser
    render_report(3, 'Name') do |od|
      usr=od.order.user
      "#{usr.full_name} (#{usr.username})"
    end
  end


  def price_group
    render_report(4, 'Name') {|od| od.price_policy ? od.price_policy.price_group.name : 'Unassigned' }
  end


  private

  def init_report_params
    os, status_id=nil, params[:status_filter]

    if status_id.blank?
      os=OrderStatus.complete.first
    elsif status_id.to_i != -1 # not all
      os=OrderStatus.find(status_id.to_i)
    end

    if os
      @selected_status_id=os.id
      @status_ids=(os.root? ? os.children.collect(&:id) : []).push(os.id)
    else
      @selected_status_id=-1
      @status_ids=OrderStatus.non_protected_statuses(current_facility).collect(&:id)
    end

    super
  end
  
  
  def init_report_headers(report_on_label)
    @headers=[ report_on_label, 'Quantity', 'Total Cost', 'Percent of Cost' ]
  end
  
  
  def init_report_data(report_on_label, &report_on)
    @report_on=report_on
    init_report_headers report_on_label
    @total_cost, @report_data=0.0, report_data.all       
    @report_data.each {|od| @total_cost += od.total }    
  end
  

  def init_report(report_on_label)
    sums, rows, @total_quantity, @total_cost={}, [], 0, 0.0
    init_report_headers report_on_label

    report_data.all.each do |od|
      key=yield od
      sums[key]=[0,0] unless sums.has_key?(key)
      sums[key][0] += od.quantity
      @total_quantity += od.quantity
      sums[key][1] += od.total
      @total_cost += od.total
    end

    sums.each do |k,v|
      frac_cost=@total_cost > 0 ? v[1] / @total_cost : 1
      rows << v.push(frac_cost * 100).unshift(k)
    end

    rows.sort! {|a,b| a.first <=> b.first}
    page_size=25
    page=params[:page].blank? || rows.size < page_size ? 1 : params[:page].to_i    
    #page=1 if (rows.size / page_size).to_i < page
        
    @rows=WillPaginate::Collection.create(page, page_size) do |pager|       
      pager.replace rows[ pager.offset, pager.per_page ]
      pager.total_entries=rows.size unless pager.total_entries
    end
  end
  
  
  def report_data
    OrderDetail.joins(:order_status).
               where('order_statuses.id' => @status_ids).
               joins('LEFT JOIN orders ON order_details.order_id = orders.id').
               where('orders.facility_id = ? AND orders.ordered_at >= ? AND orders.ordered_at <= ?', current_facility.id, @date_start, @date_end).
               includes(:order, :account, :price_policy, :product)
  end
  
end