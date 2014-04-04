require 'spec_helper'

describe SurveyResponse do
  include_context 'external service'

  let :deserialized_response_data do {
    show_url: params[:survey_url],
    edit_url: params[:survey_edit_url]
  } end


  subject(:survey_response) { described_class.new params }


  it 'has a params accessor' do
    expect(survey_response.params).to eq params
  end

  it 'gives a String of URL JSON' do
    expect(survey_response.response_data).to eq deserialized_response_data.to_json
  end

  it 'provides a Surveyor edit URL if an edit URL is not given' do
    params[:survey_edit_url] = nil
    deserialized_response_data[:edit_url] = "#{params[:survey_url]}/take"
    expect(survey_response.response_data).to eq deserialized_response_data.to_json
  end

  it 'creates an external service receiver' do
    expect(survey_response).to_not be_nil
    expect { survey_response.save! }.to change{ ExternalServiceReceiver.count }.by 1
    esr = ExternalServiceReceiver.last
    expect(esr.receiver).to eq external_service_receiver.receiver
    expect(esr.external_service).to eq external_service
    expect(esr.response_data).to eq deserialized_response_data.to_json
  end

  it 'merges the order detail' do
    od = external_service_receiver.receiver
    expect(OrderDetail).to receive(:find).and_return od
    expect(od).to receive :merge!
    survey_response.save!
  end

end
