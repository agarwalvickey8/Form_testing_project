require 'net/http'
require 'benchmark'
require 'base64'
require 'digest'
require 'securerandom'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'faker'
require 'openssl'
require_relative '../helpers/search_helper.rb'
Helper = SearchHelper
$options = {
	ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER
}
class SearchController < ApplicationController
	def search
		@url = params[:url]
		if !@url.nil?
			begin
				if !@url.end_with?("/")
					@url = @url + "/"
				end
				@map_results = []
				data_code, data_body = send_request_to_plugin(@url)
				if data_code != '200'
					@map_results.append({'pluginrequesterror' => 'Plugin is not installed on the website.'})
				else
					@results = JSON.parse(data_body)
					if !@results.nil?
						#count = @results["totalurlcount"]
						#render json: { message: 'Data available', data: count }
						@results.each do |form_type, result|	
							case form_type	
							when "nf"
								@nf = NF.new
								@map_results = @map_results.concat(@nf.solve_nf(result, @url))
							when "cf7"
								@cf = CF7.new
								@map_results = @map_results.concat(@cf.solve_cf7(result, @url))
							when "wp"
								@wp = WPForms.new
								@map_results = @map_results.concat(@wp.solvewpforms(result, @url))
							when "ff"
								@ff = FluentForms.new
								@map_results = @map_results.concat(@ff.solvefluentforms(result, @url))
							when "formidable"
								@formidable = FormidableFormTests.new
								@map_results = @map_results.concat(@formidable.solve(result, @url))	
							when "forminator"
								@forminator = ForminatorFormTests.new
								@map_results = @map_results.concat(@forminator.solve(result, @url))	
							else
							end
						end
					end	
				end
				render json: { mapResult: @map_results }
			end
		end
	end

	def send_request_to_plugin(url)
		url = (url + "?formtesting=true")
		uri = URI(url)
		http = Net::HTTP.new(uri.host, uri.port)
		if url.include? "https"
			http.use_ssl = true			
		end
		http.read_timeout = 10
		request = Net::HTTP::Get.new(uri)
		response = http.request(request)
		return response.code, response.body
	rescue
		return "400","Plugin not installed error."
	end
end

class CF7
	def solve_cf7(results, url)
		map_result = []
		results.each do |result|
			result = result[1]
			map_form_results = {}
			formid = result['formid']
			formurls = result['formurls']
			formname = result['formname']
			formfields = result['formfields']
			formaction = result['formaction']
			form_action_key = formaction.split('#', 2)
			formactionurl = formurls[0] + '#' + form_action_key.last
			email = result['email']
			email_disabled = result['emaildisabled']
			additional_settings = result['additionalsettings']
			map_form_results['formid'] = formid
			map_form_results['formurls'] = formurls		

			key = ""
			formfields.each do |formfield|
				name = formfield["name"]
				if name == "_wpcf7_unit_tag"
					key = formfield["value"]
				end
			end

			key_parts = key.split('-') 
			key = key_parts[0] + "-" + key_parts[1]
			form_html = get_html(key, formurls[0])
			screenshots = Helper.getscreenshots(key, formurls)
			map_form_results['screenshots'] = screenshots
			map_form_results['formname'] = formname
			map_form_results['formtype'] = "Contact Form 7"
			map_form_results['formfieldsfromdb'] = formfields
			map_form_results['formaction'] = formactionurl
			map_form_results['email'] = email
			map_form_results['emaildisabled'] = email_disabled
			map_form_results['emailhost'] = email['recipient']
			map_form_results['additionalsettings'] = additional_settings	
			html_fields_array = []	
			inputs = []
			filename = ""
			begin
				inputs_array = form_html.css('input', 'textarea')	
				inputs_array.each do |field|	
					name = field.attributes["name"].try(:value)
					type = field.attributes["type"].try(:value)	
					if "file" == type
						extensions = field.attributes["accept"].try(:value)	
						if extensions.include? "image"
							extension = ".png"
						elsif extensions.include? "video"
							extension = ".mp4"
						elsif extensions.include? "audio"
							extension = ".mp3"
						else
							extensions_array = extensions.split(',')
							extension = extensions_array[0]
						end
						filename = "dummy#{extension}"	
					end
					if !name.nil?
						inputs.append(name)
					end
					html_fields_array << {"name": name, "type":type}
				end
				map_form_results['formfieldsfromhtml'] = inputs
				fields_validated, missing_fields = Helper.validate_form(inputs, formfields)	
				map_form_results['fieldsvalidated'] = fields_validated
			rescue
				map_form_results['fieldsvalidated'] = false
				map_form_results['formvalidationerror'] = 'Field validation unsuccessful. Error fetching form fields.'
			end

			file_field_present, sample_values = Helper.generate_sample_values(filename, formfields, formurls[0], formid, formname)
			form_field_count = Helper.get_form_field_count(sample_values)
			map_form_results['formfieldcount'] = form_field_count
			sample_values = Helper.refine_sample_values(sample_values)
			map_form_results['samplevalues'] = sample_values
			if fields_validated
				submit_url = url + 'index.php/wp-json/contact-form-7/v1/contact-forms/' + formid + '/feedback'
				post_response_code, post_response_body = send_post_request(submit_url, sample_values, email_disabled, map_form_results['emailhost'])
				map_form_results['formsubmitted'] = false
				map_form_results['formvalidationerror'] = 'None'
				if post_response_code != "404"
					post_response_body = JSON.parse(post_response_body)
					case post_response_body["status"]
					when "mail_sent"
						map_form_results['formsubmitted'] = true
						map_form_results['formvalidationerror'] = 'None'
					when "mail_failed"
						map_form_results['formsubmitted'] = false
						map_form_results['formvalidationerror'] = 'Invalid email address or a server error.'
					when "validation_error"
						map_form_results['formsubmitted'] = false
						map_form_results['formvalidationerror'] = 'One or more required fields are missing or have incorrect values.'
					when "spam"
						map_form_results['formsubmitted'] = false
						map_form_results['formvalidationerror'] = 'Form submission is detected as spam.'
					end
				else
					map_form_results['formsubmitted'] = false
					map_form_results['formvalidationerror'] = post_response_body
				end
			else
				map_form_results['formsubmitted'] = false
				if map_form_results['formvalidationerror'].nil? or map_form_results['formvalidationerror'].empty?
					map_form_results['formvalidationerror'] = "Field validation unsuccessful.\nMissing fields are : #{missing_fields}."
				end
			end
			if !map_form_results['formsubmitted'] || !map_form_results['fieldsvalidated']
				map_form_results['formvalidated'] = false
			else
				map_form_results['formvalidationerror'] = 'Field validation unsuccessful.'
			end

			Helper.ss_after_submission(key, formurls, map_form_results, screenshots)

			map_form_results["formvalidated"] = map_form_results["fieldsvalidated"] && map_form_results["formsubmitted"] && map_form_results["screenshotsvalidated"]

			map_result << map_form_results
		end
		map_result
	end

	def update_sample_values(sample_values, form_html)
		updated_sample_values = []
		inputs_array = form_html.css('input, textarea')
		inputs = []
		inputs_array.each do |field|
			type_i = field.attributes["type"].try(:value)
			if type_i == 'hidden'
				next
			end
			name = field.attributes["name"].try(:value)
			label = field.parent.parent.css('label').first
			if label.present? && !label.empty?
				name = label.text.strip
			end
			sample_values.each do |sample_value|
				id = sample_value['id']
				type = sample_value['type']
				value = sample_value['value']
				if type == type_i
					updated_sample_values << {"id" => id, "name" => name, "type" => type, "value" => value }	
				end
			end
		end	
		updated_sample_values
	end

	def get_html(formid, formurl)
		uri = URI.parse("http://localhost:3003/search")
		header = {'Content-Type': 'text/json'}
		body = { url: formurl }
		http = Net::HTTP.new(uri.host, uri.port)
		request = Net::HTTP::Post.new(uri.request_uri, header)
		request.body = body.to_json
		response = http.request(request)
		html_content = response.body
		get_form_html(html_content, formid)
	rescue
		return nil
	end

	def get_form_html(html_content, formid)
		doc = Nokogiri::HTML(html_content)
		form = doc.css("div[id^=\"#{formid}\"]")
		form
	end

	def get_html2(formid, url)		
		html_content = URI.open(url).read
		get_form_html(html_content, formid)
	end

	def send_post_request(url, data, email_disabled, email_host)
		boundary = "----WebKitFormBoundary#{SecureRandom.hex(8)}"
		headers = {
			'Content-Type' => "multipart/form-data; boundary=#{boundary}"
		}
		uri = URI.parse(url)
		http = Net::HTTP.new(uri.host, uri.port)
		if url.include? "https"
			http.use_ssl = true
		end
		request = Net::HTTP::Post.new(uri.path, headers)
		post_body = []
		data.each do |data|
			post_body << "--#{boundary}\r\n"
			if data["type"] != "file"
				post_body << "Content-Disposition: form-data; name=\"#{data["name"]}\"\r\n\r\n"
				post_body << "#{data["value"]}\r\n"
			else
				file_data = File.read(data["value"], mode: 'rb')
				file_name = data["value"].split('/', -1).last
				post_body << "Content-Disposition: form-data; name=\"#{data["name"]}\"; filename=\"#{file_name}\"\r\n\r\n"
				post_body << "Content-Type: #{Helper.mime_type(data["value"])}\r\n\r\n"
				post_body << file_data
				post_body << "\r\n"
			end
		end
		post_body << "--#{boundary}--\r\n"
		request.body = post_body.join
		response = http.request(request)		
		return response.code, response.body
	rescue
		return "404", "Some error occured during form submission."
	end
end

class NF
	def solve_nf(results, url)	
		map_result = []
		results.each do |result|
			result = result[1]
			map_form_results = {}
			formid = result['formid']
			formurls = result['formurls']
			formname = result['formname']
			formfields = result['formfields']
			formlabels = result['formlabels']
			email = result['email']
			email_disabled = result['emaildisabled']	
			additional_settings = result['additionalsettings']
			map_form_results['formid'] = formid
			map_form_results['formurls'] = formurls
			key = "nf-form-#{formid}-cont"
			screenshots = Helper.getscreenshots(key, formurls)	
			map_form_results['screenshots'] = screenshots
			map_form_results['formname'] = formname
			map_form_results['formtype'] = "Ninja Form"
			map_form_results['formfieldsfromdb'] = formfields
			map_form_results['email'] = email
			map_form_results['emaildisabled'] = email_disabled
			map_form_results['emailhost'] = ""
			map_form_results['additionalsettings'] = additional_settings

			form_html = get_html(key, formurls[0])	

			inputs = []
			begin
				inputs_array = form_html.css("div.nf-field-label")
				inputs = inputs_array.map { |label| label.text.strip }
				inputs.pop()

				map_form_results['formfieldsfromhtml'] = inputs
				fields_validated, missing_fields = Helper.validate_form(inputs, formfields)	
				map_form_results['fieldsvalidated'] = fields_validated
			rescue
				map_form_results['fieldsvalidated'] = false
				map_form_results['formvalidationerror'] = 'Field validation unsuccessful. Error fetching form fields.'
			end

			filename = ""
			file_field_present, sample_values = Helper.generate_sample_values(filename, formfields, formurls[0], formid, formname)	
			form_field_count = Helper.get_form_field_count(sample_values)
			map_form_results['formfieldcount'] = form_field_count
			sample_values = Helper.refine_sample_values(sample_values)
			map_form_results['samplevalues'] = sample_values
			if fields_validated
				submit_url = url + 'wp-admin/admin-ajax.php'
				post_response_code, post_response_body = send_post_request(formid, submit_url, result, sample_values, true, "")	
				map_form_results['formsubmitted'] = false
				map_form_results['formvalidationerror'] = 'None'
				if post_response_code != "404"
					post_response_body = JSON.parse(post_response_body)
					if (post_response_body["data"]["actions"]["success_message"] != nil)
						map_form_results['formsubmitted'] = true
						map_form_results['formvalidationerror'] = 'None'
					end
					case post_response_body["data"]["actions"]["email"]["sent"]
					when true
						map_form_results['formsubmitted'] = true
						map_form_results['formvalidationerror'] = 'None'
					when false
						map_form_results['formsubmitted'] = true
						map_form_results['formvalidationerror'] = 'Mail not sent. Invalid email address or a server error.'
					end
				else
					map_form_results['formsubmitted'] = false
					map_form_results['formvalidationerror'] = post_response_body
				end
			else
				map_form_results['formsubmitted'] = false
				if map_form_results['formvalidationerror'].nil? or map_form_results['formvalidationerror'].empty?
					map_form_results['formvalidationerror'] = "Field validation unsuccessful.\nMissing fields are : #{missing_fields}."
				end
			end
			Helper.ss_after_submission(key, formurls, map_form_results, screenshots)
			map_form_results["formvalidated"] = map_form_results["fieldsvalidated"] && map_form_results["formsubmitted"] && map_form_results["screenshotsvalidated"]

			map_result << map_form_results	
		end
		map_result	
	end

	def get_html(formid, formurl)
		uri = URI.parse("http://localhost:3003/search")
		header = {'Content-Type': 'text/json'}
		body = { url: formurl }
		http = Net::HTTP.new(uri.host, uri.port)
		request = Net::HTTP::Post.new(uri.request_uri, header)
		request.body = body.to_json
		response = http.request(request)
		html_content = response.body
		get_form_html(html_content, formid)
	rescue
		return nil
	end

	def get_form_html(html_content, partial_id)
		doc = Nokogiri::HTML(html_content)
		form = doc.css("*[id*='#{partial_id}'], *[action*='#{partial_id}'], *[class*='#{partial_id}'], *[name*='#{partial_id}'], *[data-*='#{partial_id}']")	
		form
	end

	def send_post_request(formid, url, result, formfields, email_disabled, email_host)
		array = result['settings']
		uri = URI.parse(url)
		post_body = []
		fields = {}
		formfields.each do |data|	
			fields[data["id"].to_i] = { "value" => data["value"], "id" => data["id"].to_i }
		end	
		settings = get_settings(array)	
		formData = []
		formData = {
			"id" => formid,
			"fields" => fields,
			"settings" => settings,
			"extra" => result['extra']
		}	
		action = 'nf_ajax_submit'
		security = result['nonce']	
		post_body = {
			"action" => action,
			"security" => security,
			"formData" => formData.to_json
		}	
		http = Net::HTTP.new(uri.host, uri.port)
		if url.include? "https"
			http.use_ssl = true
		end
		request = Net::HTTP::Post.new(uri.request_uri)
		request.set_form_data(post_body)
		request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
		response = http.request(request)	
		return response.code, response.body
	rescue
		return "404", "Some error occured during form submission."
	end

	def get_settings(settings_array)
		settings = []
		settings = {
		'objectType' => settings_array['objectType'],
		'editActive' => settings_array['editActive'],
		'title' => settings_array['title'],
		'show_title' => settings_array['show_title'],
		'allow_public_link' => settings_array['allow_public_link'],
		'embed_form' => settings_array['embed_form'],
		'clear_complete' => settings_array['clear_complete'],
		'hide_complete' => settings_array['hide_complete'],
		'default_label_pos' => settings_array['default_label_pos'],
		'wrapper_class' => settings_array['wrapper_class'],
		'element_class' => settings_array['element_class'],
		'form_title_heading_level' => settings_array['form_title_heading_level'],
		'key' => settings_array['key'],
		'add_submit' => settings_array['add_submit'],
		'currency' => settings_array['currency'],
		'unique_field_error' => settings_array['unique_field_error'],
		'logged_in' => settings_array['logged_in'],
		'not_logged_in_msg' => settings_array['not_logged_in_msg'],
		'sub_limit_msg' => settings_array['sub_limit_msg'],
		'calculations' => settings_array['calculations'],
		'ninjaForms' => settings_array['ninjaForms'],
		'changeEmailErrorMsg' => settings_array['changeEmailErrorMsg'],
		'changeDateErrorMsg' => settings_array['changeDateErrorMsg'],
		'confirmFieldErrorMsg' => settings_array['confirmFieldErrorMsg'],
		'fieldNumberNumMinError' => settings_array['fieldNumberNumMinError'],
		'fieldNumberNumMaxError' => settings_array['fieldNumberNumMaxError'],
		'fieldNumberIncrementBy' => settings_array['fieldNumberIncrementBy'],
		'fieldTextareaRTEInsertLink' => settings_array['fieldTextareaRTEInsertLink'],
		'fieldTextareaRTEInsertMedia' => settings_array['fieldTextareaRTEInsertMedia'],
		'fieldTextareaRTESelectAFile' => settings_array['fieldTextareaRTESelectAFile'],
		'formErrorsCorrectErrors' => settings_array['formErrorsCorrectErrors'],
		'formHoneypot' => settings_array['formHoneypot'],
		'validateRequiredField' => settings_array['validateRequiredField'],
		'honeypotHoneypotError' => settings_array['honeypotHoneypotError'],
		'fileUploadOldCodeFileUploadInProgress' => settings_array['fileUploadOldCodeFileUploadInProgress'],
		'fileUploadOldCodeFileUpload' => settings_array['fileUploadOldCodeFileUpload'],
		'currencySymbol' => settings_array['currencySymbol'],
		'fieldsMarkedRequired' => settings_array['fieldsMarkedRequired'],
		'thousands_sep' => settings_array['thousands_sep'],
		'decimal_point' => settings_array['decimal_point'],
		'siteLocale' => settings_array['siteLocale'],
		'dateFormat' => settings_array['dateFormat'],
		'startOfWeek' => settings_array['startOfWeek'],
		'of' => settings_array['of'],
		'previousMonth' => settings_array['previousMonth'],
		'nextMonth' => settings_array['nextMonth'],
		'months' => settings_array['months'],
		'monthsShort' => settings_array['monthsShort'],
		'weekdays' => settings_array['weekdays'],
		'weekdaysShort' => settings_array['weekdaysShort'],
		'weekdaysMin' => settings_array['weekdaysMin'],
		'recaptchaConsentMissing' => settings_array['recaptchaConsentMissing'],
		'recaptchaMissingCookie' => settings_array['recaptchaMissingCookie'],
		'recaptchaConsentEvent' => settings_array['recaptchaConsentEvent'],
		'currency_symbol' => settings_array['currency_symbol'],
		'beforeForm' => settings_array['beforeForm'],
		'beforeFields' => settings_array['beforeFields'],
		'afterFields' => settings_array['afterFields'],
		'afterForm' => settings_array['afterForm']
		}
		settings
	end
end

class WPForms
	def solvewpforms(results, site_url)
		map_result = []
		results.each do |result|
			result = result[1]
			map_form_results = {}
			formid = result['formid']
			formurls = result['formurls']
			formname = result['formname']
			formfields = result['formfields']
			email = result['email']
			email_disabled = result['emaildisabled']
			additional_settings = result['additionalsettings']
			map_form_results['formid'] = formid
			map_form_results['formurls'] = formurls
			key = "wpforms-form-#{formid}"
			formtype = "WPForms"
			screenshots = Helper.getscreenshots(key, formurls)
			map_form_results['screenshots'] = screenshots
			map_form_results['formname'] = formname
			map_form_results['formtype'] = formtype
			map_form_results['formfieldsfromdb'] = formfields
			map_form_results['email'] = email
			map_form_results['emaildisabled'] = email_disabled
			map_form_results['emailhost'] = ""
			map_form_results['additionalsettings'] = additional_settings
			html = URI.open(formurls[0]).read
			doc = Nokogiri::HTML(html)
			if doc
				form_id = "wpforms-#{formid}"
				form = doc.css("div[id^='#{form_id}-field_']")
				labels = form.css('label.wpforms-field-label', 'legend.wpforms-field-label')
				inputs = labels.map { |label| label.text.strip }

				begin
					map_form_results['formfieldsfromhtml'] = inputs
					fields_validated, missing_fields = Helper.validate_form(inputs, formfields)
					map_form_results['fieldsvalidated'] = fields_validated	
				rescue
					map_form_results['fieldsvalidated'] = false
					map_form_results['formvalidationerror'] = 'Field validation unsuccessful. Error fetching form fields.'
				end

				sample_values, present_field_values, file_field_present = generate_payload(formfields, formurls[0], site_url, result, formtype)
				form_field_count = Helper.get_form_field_count(present_field_values)
				map_form_results['formfieldcount'] = form_field_count
				map_form_results['samplevalues'] = present_field_values
				if fields_validated
					post_response_code, post_response_body = form_submission(sample_values, site_url, formid, file_field_present)
					map_form_results['formsubmitted'] = false
					map_form_results['formvalidationerror'] = 'None'
					if post_response_code != "404"
						post_response_body = JSON.parse(post_response_body)
						if (post_response_body["success"])
							map_form_results['formsubmitted'] = true
							map_form_results['formvalidationerror'] = 'None'
						else
							map_form_results["formvalidationerror"] = "Error in form submission."
						end
					else
						map_form_results['formsubmitted'] = false
						map_form_results['formvalidationerror'] = post_response_body
					end
				else
					map_form_results['formsubmitted'] = false
					if map_form_results['formvalidationerror'].nil? or map_form_results['formvalidationerror'].empty?
						map_form_results['formvalidationerror'] = "Field validation unsuccessful.\nMissing fields are : #{missing_fields}"
					end
				end
				Helper.ss_after_submission(key, formurls, map_form_results, screenshots)
				map_form_results["formvalidated"] = map_form_results["fieldsvalidated"] && map_form_results["formsubmitted"] && map_form_results["screenshotsvalidated"]
			end
			map_result << map_form_results
		end
		map_result
	end

	def self.get_image_data(form_id, field_id, form_url)
		html_code = URI.open(form_url).read
		doc = Nokogiri::HTML(html_code)
		uploader_divs = doc.css('div.wpforms-uploader')
		extensions = ""
		chunk_size = ""
		uploader_divs.each do |uploader_div|
			if (uploader_div['data-form-id'] == form_id && uploader_div['data-field-id'] == field_id)
				extensions = uploader_div['data-extensions']
				chunk_size = uploader_div['data-file-chunk-size']
			end
		end
		extensions_array = extensions.split(',')
		extension = extensions_array[0]
		filename = "dummy.#{extension}"
		filepath = "./#{filename}"
		base64_image = File.open(filepath, "rb") do |file|
			Base64.strict_encode64(file.read)
		end
		binary_data = Base64.decode64(base64_image)
		uuid = SecureRandom.uuid.gsub('-', '')
		formatted_uuid = "#{uuid[0..7]}-#{uuid[8..11]}-#{uuid[12..15]}-#{uuid[16..19]}-#{uuid[20..31]}"
		data = {
			"action" => "wpforms_upload_chunk_init",
			"form_id" => form_id,
			"field_id" => field_id,
			"name" => filename,
			"slow" => "false",
			"dzuuid" => formatted_uuid,
			"dzchunkindex" => "0",
			"dztotalfilesize" => "108",
			"dzchunksize" => chunk_size,
			"dzchunkbyteoffset" => "0"
		}
		new_url = form_url + "/wp-admin/admin-ajax.php"
		uri = URI.parse(new_url)
		request = Net::HTTP::Post.new(uri)
		request.set_form data,'multipart/form-data'
		response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
			http.request(request)
		end
		response_body = JSON.parse(response.body)
		response_data = response_body["data"]
		dzchunksize = response_data["dzchunksize"]
		content_type = 'application/octet-stream'
		file_part = "Content-Disposition: form-data; name=\"#{field_label}\"; filename=\"#{File.basename(filepath)}\"\r\n" +
		"Content-Type: application/octet-stream\r\n\r\n#{binary_data}\r\n"
		fields = {
			'dzuuid' => formatted_uuid,
			'dzchunkindex' => '0',
			'dztotalfilesize' => '108',
			'dzchunksize' => dzchunksize,
			'dztotalchunkcount' => '1',
			'dzchunkbyteoffset' => '0',
			'action' => 'wpforms_upload_chunk',
			'form_id' => form_id,
			'field_id' => field_id,
		}
		boundary = "----RubyFormBoundary#{rand(100000)}"
		body = fields.map { |name, value| "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n" }.join("") + "--#{boundary}\r\n#{file_part}" + "--#{boundary}--\r\n"
		request = Net::HTTP::Post.new(uri.path)
		request.content_type = "multipart/form-data; boundary=#{boundary}"
		request.body = body
		response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
			http.request(request)
		end
		final_payload = {
			"action": "wpforms_file_chunks_uploaded",
			"form_id": form_id,
			"field_id": field_id,
			"name": filename,
			"dzuuid": formatted_uuid,
			"dzchunkindex": 0,
			"dztotalfilesize": 108,
			"dzchunksize": dzchunksize,
			"dztotalchunkcount": 1,
			"dzchunkbyteoffset": 0
		}
		request = Net::HTTP::Post.new(uri)
		request.set_form(final_payload)
		response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
			http.request(request)
		end
		response_data = JSON.parse(response.body)
		value = response_data["data"]
		add_array = [value]
		add_json = add_array.to_json
		field_value = "#{add_json}"
		field_value
	end

	def generate_payload(form_fields, html_url, form_url, result, formname)
		response = URI.open(html_url).read
		parsed_html = Nokogiri::HTML(response)
		forms = parsed_html.css('form[data-token]')
		token = forms.any? { |form| form['data-formid'] == result["formid"] } ? forms.find { |form| form['data-formid'] == result["formid"] }['data-token'] : nil
		present_fields_values = []
		filename = ""
		file_field_present, sample_values = Helper.generate_sample_values(filename, form_fields, form_url, result["formid"], formname)
		sample_values.each do |sample_value|
			present_fields_values << sample_value
		end	
		sample_values << {"label" => "wpforms[id]", "value" => result["formid"]}
		sample_values << {"label" => "wpforms[nonce]", "value" => result["nonce"]}
		sample_values << {"label" => "wpforms[author]", "value" => result["author"]}
		sample_values << {"label" => "wpforms[post_id]", "value" => result["postid"]}
		sample_values << {"label" => "wpforms[submit]", "value" => "wpforms-submit"}
		sample_values << {"label" => "wpforms[token]", "value" => token}
		sample_values << {"label" => "action", "value" => "wpforms_submit"}
		sample_values << {"label" =>"page_url", "value" => html_url}
		sample_values << {"label" =>"page_title", "value" => result["formname"]}
		sample_values << {"label" =>"page_id" , "value" => "#{result["pageid"]}"}
		return sample_values, present_fields_values, file_field_present
	end

	def form_submission(sample_values, site_url, form_id, file_field_present)
		extended_url = file_field_present ? "?wpforms_form_id=#{form_id}" : "/wp-admin/admin-ajax.php"
		new_url = site_url+ extended_url
		data = sample_values.map { |obj| [obj["label"], obj["value"]] }.to_h
		response = Helper.post_request(new_url, data)
		return response.code, response.body
	rescue
		return "404", "Some error occured during form submission."
	end
end

class FluentForms
	def solvefluentforms(results, site_url)
		map_result = []
		results.each do |result|
			result = result[1]
			map_form_results = {}
			formid = result['formid']
			formurls = result['formurls']
			formname = result['formname']
			formfields = result['formfields']
			email = result['email']
			email_disabled = result['emaildisabled']
			additional_settings = result['additionalsettings']
			map_form_results['formid'] = formid
			map_form_results['formurls'] = formurls
			key = "fluentform_#{formid}"
			screenshots = Helper.getscreenshots(key, formurls)
			map_form_results['screenshots'] = screenshots
			map_form_results['formname'] = formname
			map_form_results['formtype'] = "Fluent Form"
			map_form_results['formfieldsfromdb'] = formfields
			map_form_results['email'] = email
			map_form_results['emaildisabled'] = email_disabled
			map_form_results['emailhost'] = ""
			map_form_results['additionalsettings'] = additional_settings
			hidden_fields = get_hidden_fields(formid, formurls[0])
			if hidden_fields && !hidden_fields.empty?
				html = URI.open(formurls[0]).read
				doc = Nokogiri::HTML(html)
				formname = "fluentform_wrapper_#{formid}"
				form = doc.css("div[class*=\"#{formname}\"]")
				labels = form.css("div.ff-el-input--label label")
				inputs = labels.map { |label| label.text }

				begin
					map_form_results['formfieldsfromhtml'] = inputs
					fields_validated, missing_fields = validate_form(inputs, result['formlabels'])		
					map_form_results['fieldsvalidated'] = fields_validated
				rescue
					map_form_results['fieldsvalidated'] = false
					map_form_results['formvalidationerror'] = 'Field validation unsuccessful. Error fetching form fields.'
				end

				filename = ""
				file_field_present, sample_values = Helper.generate_sample_values(filename, formfields, formurls[0], formid, formname)	
				form_field_count = Helper.get_form_field_count(sample_values)
				map_form_results['formfieldcount'] = form_field_count
				map_form_results['samplevalues'] = sample_values
				if fields_validated
					post_response_code, post_response_body = form_submission(hidden_fields, sample_values, formid, site_url)
					map_form_results['formsubmitted'] = false
					map_form_results['formvalidationerror'] = 'None'
					if post_response_code != "404"
						post_response_body = JSON.parse(post_response_body)
						if (post_response_body["success"])
							map_form_results['formsubmitted'] = true
							map_form_results['formvalidationerror'] = 'None'
						else
							map_form_results["formvalidationerror"] = "Error in form submission."
						end
					else
						map_form_results['formsubmitted'] = false
						map_form_results['formvalidationerror'] = post_response_body
					end
				else
					map_form_results['formsubmitted'] = false
					if map_form_results['formvalidationerror'].nil? or map_form_results['formvalidationerror'].empty?
						map_form_results['formvalidationerror'] = "Field validation unsuccessful.\nMissing fields are #{missing_fields}"
					end
				end
				Helper.ss_after_submission(key, formurls, map_form_results, screenshots)
				map_form_results["formvalidated"] = map_form_results["fieldsvalidated"] && map_form_results["formsubmitted"] && map_form_results["screenshotsvalidated"]
			end
			map_result << map_form_results
		end
		map_result
	end

	def validate_form(html_fields, db_fields)
		html_names = []
		html_fields.each do |field|	
			html_names.append(field.gsub(" *", ""))
		end	
		missing_fields = db_fields - (html_names & db_fields)
		return missing_fields.empty?, missing_fields
	end


	def form_submission(hidden_fields, sample_values, form_id, site_url)
		hidden_data = hidden_fields.map { |field| "#{field['name']}=#{CGI.escape(field['value'].to_s)}" }.join('&')
		sample_data = sample_values.map { |field| "#{field['label']}=#{CGI.escape(field['value'].to_s)}" }.join('&')
		data = hidden_data + "&" + sample_data
		payload = {
			'data': data,
			'action': 'fluentform_submit',
			'form_id': form_id
		}
		current_time = Time.now
		timestamp = (current_time.to_i * 1000) + (current_time.usec / 1000)
		new_url = site_url + "/wp-admin/admin-ajax.php?t=#{timestamp}"
		response = Helper.post_request(new_url, payload)
		return response.code, response.body
	rescue
		return "404", "Some error occured during form submission."
	end

	def get_hidden_fields(form_id, form_url)
		html = URI.open(form_url).read
		doc = Nokogiri::HTML(html)
		hidden_fields = []
		form = doc.at_css("#fluentform_#{form_id}")
		inputs = form.css('input, textarea, select')
		inputs.each do |input|
			name = input['data-name'] || input['name']
			type = input['type']
			if 'hidden' == type
				hidden_fields << {"name" => name, "type" => type, "value" => input['value']}
			end
		end
		hidden_fields
	end
end

class FormidableFormTests
	def solve(forms_data, site_url)
		results = []
		forms_data.each do |form|
			form = form[1]	
			result = {}
			result["formid"] = form["formid"]
			result["formurls"] = form["formurls"] 
			key = "frm_form_#{form["formid"]}_container"
			screenshots = Helper.getscreenshots(key, form["formurls"])
			result["screenshots"] = screenshots
			result["formname"] = form["formname"]
			result["formtype"] = "Formidable Forms"
			result["formfieldsfromdb"] = form["formfields"]
			result["email"] = nil
			result["emaildisabled"] = nil
			result["emailhost"] = nil
			result["additionalsettings"] = nil
			url = URI(form["formurls"][0])
			doc = Nokogiri::HTML.parse(Net::HTTP.get(url))
			fields_missing = []
			begin
				error = false
				form["formfields"].each do |field|
					field_label = doc.css("#field_"+field["field_key"]+"_label").first
					if field_label.nil?
						fields_missing.append(field['formname'])
						error = true
					end
				end
				result["fieldsvalidated"] = !error	
				if error
					result["formvalidationerror"] = "Field validation unsuccessful.\nMissing fields are : #{fields_missing}"
				end
			rescue
				map_form_results['fieldsvalidated'] = false
				map_form_results['formvalidationerror'] = 'Field validation unsuccessful. Error fetching form fields.'
			end

			result["formfieldcount"] = form["formfields"].length
			http = Net::HTTP.new(url.host, url.port)
			if form["formurls"][0].include? "https"
				http.use_ssl = true
			end
			request = Net::HTTP::Post.new(url)
			form_submit_data, sample_data = generate_sample_data(form["formid"], doc)
			result["samplevalues"] = sample_data
			form_submit_data['form_id'] = "#{form["formid"]}"
			antispam_token = doc.at('form')['data-token']
			if antispam_token
				form_submit_data['antispam_token'] = antispam_token
			end
			request["Content-Type"] = 'application/x-www-form-urlencoded'
			request.set_form_data(form_submit_data)
			response = http.request(request)
			response_html = Nokogiri::HTML.parse(response.body)	
			success_msg = response_html.css('.frm_message').css('p').text.strip
			if success_msg == "Your responses were successfully submitted. Thank you!"
				result["formsubmitted"] = true
			else
				result["formsubmitted"] = false
				result["formvalidationerror"] = "Error in form submission."
			end
			Helper.ss_after_submission(key, form["formurls"], result, screenshots)
			result["formvalidated"] = result["fieldsvalidated"] && result["formsubmitted"] && result["screenshotsvalidated"]
			results << result
		end
		results
	end

	def generate_sample_data(form_id, parsed_html)
		form_to_test = nil
		parsed_html.css('form').each do |form|
			if form.css('input[name="form_id"]').attr('value').to_s == form_id
				form_to_test = form
				break
			end
		end
		sample_data = []
		form_submit_data = {}
		fields = form_to_test.css('input') + form_to_test.css('textarea')
		antispam_token = form_to_test['data-token']
		if antispam_token
			form_submit_data["antispam_token"] = antispam_token
		end	
		fields.each do |field|
			name = field.attr('name')
			type = field.attr('type')
			if type.nil?
				if field.name == 'textarea'
					type = 'textarea'
				end
			end
			value = ''
			case type
			when 'text'
				value = Faker::Lorem.sentence
			when 'textarea'
				value = Faker::Lorem.sentence
			when 'email'
				value = Faker::Internet.email
			when 'tel'
				value = Faker::Base.numerify('(###) ### ####')
			when 'date'
				value = Faker::Date.between(from: Date.today - 365, to: Date.today)
			when 'number'
				value = 2485729
			when 'checkbox'
				value = [true, false].sample
			when 'radio'
				options = form_to_test.css("input[name=#{name}]")
				value = options[rand(options.length)].attr('value')
			when 'file'
				field_id = name.scan(/\d+/).first
				script_tag = doc.at('script:contains("var frm_js")')
				nonce_value = script_tag.text.match(/"nonce":\s*"(.*?)"/)&.captures&.first
				script_tag = doc.at('script:contains("__frmDropzone")')
				accepted_files = []
				if script_tag
					match_data = script_tag.text.match(/__frmDropzone=(\[.*?\]);/)
					if match_data
						json_str = match_data[1].gsub(/(?<=\w)\\?\//, '/')
						json_obj = JSON.parse(json_str).first
						accepted_files = json_obj['acceptedFiles'].split(",").map do |item|
							item.strip
						end
					end
				end
				mime_type = accepted_files[0]
				filename = "sample.#{mime_type.split('/')[1]}"
				filepath = "./#{filename}"
				file_upload_url = URI.join(url, '/wp-admin/admin-ajax.php')
				request = Net::HTTP::Post.new(file_upload_url.request_uri)
				http = Net::HTTP.new(file_upload_url.host, file_upload_url.port)
				http.use_ssl = (file_upload_url.scheme == "https")
				boundary = "---------------------------#{rand(10**10)}#{rand(10**10)}#{rand(10**10)}"
				request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
				body = []
				body << "--#{boundary}\r\n"
				body << "Content-Disposition: form-data; name=\"action\"\r\n\r\n"
				body << "frm_submit_dropzone\r\n"
				body << "--#{boundary}\r\n"
				body << "Content-Disposition: form-data; name=\"field_id\"\r\n\r\n"
				body << "#{field_id}\r\n"
				body << "--#{boundary}\r\n"
				body << "Content-Disposition: form-data; name=\"form_id\"\r\n\r\n"
				body << "#{form_id}\r\n"
				body << "--#{boundary}\r\n"
				body << "Content-Disposition: form-data; name=\"nonce\"\r\n\r\n"
				body << "#{nonce_value}\r\n"
				body << "--#{boundary}\r\n"
				body << "Content-Disposition: form-data; name=\"file#{field_id}\"; filename=\"#{filename}\"\r\n"
				body << "Content-Type: #{mime_type}\r\n\r\n"
				body << File.read(filepath)
				body << "\r\n--#{boundary}--\r\n"
				request.body = body.join
				response = http.request(request)
				filecode = JSON.parse(response.body)[0]
				form_submit_data["item_meta[#{field_id}]"] = filecode
			when 'textarea'
				value = Faker::Lorem.paragraph
			when 'range'
				value = field.attr('max')
			when 'hidden'
				if !form_submit_data.key?(name)
					value = field.attr('value')
				end
			end
			if name.starts_with?("item_meta") and type!="hidden"
				label_element = nil
				if type=="textarea"
					label_element = form_to_test.at_css("textarea[name=\"#{name}\"]").previous_element
				else
					label_element = form_to_test.at_css("input[name=\"#{name}\"]").previous_element
				end
				if !label_element.nil?
					field_name = label_element.text.strip.split("\n")[0] # Example label text: "Text\n        *\n    "\
					sample_data.append({"name" => field_name, "value" => value})
				end
			end
			form_submit_data[name] = value
		end
		# "frm_verify" has to be empty for form submission. As it has type
		# "text", it gets assigned a random value.
		form_submit_data["frm_verify"] = form_to_test.css('input[name="frm_verify"]').attr('value').to_s
		return form_submit_data, sample_data
	end
end

class ForminatorFormTests
	@has_file = false
	def solve(forms_data, site_url)
		results = []
		forms_data.each do |form|
			form = form[1]
			result = {}
			result["formid"] = form["formid"]
			result["formurls"] = form["formurls"]
			key = "forminator-module-#{form["formid"]}"
			screenshots = Helper.getscreenshots(key, form["formurls"])
			result["screenshots"] = screenshots
			result["formname"] = form["formname"]
			result["formtype"] = "Forminator Forms"
			result["email"] = nil
			result["emaildisabled"] = nil
			result["emailhost"] = nil
			result["additionalsettings"] = nil
			url = URI(form["formurls"][0])	
			doc = Nokogiri::HTML.parse(Net::HTTP.get(url))
			form_html = doc.css("form[data-form-id=#{form["formid"]}]").first
			fields = form["formfields"]
			fields_missing = []
			begin
				label_elements = form_html.css('*[class="forminator-label"]')
				fields_html = label_elements.map { |element| element.xpath('text()').text.strip }
				if fields_html.sort != fields.sort
					error = true
				end
				result["fieldsvalidated"] = !error
				result["formvalidationerror"] = "Field validation unsuccessful."
			rescue
				map_form_results['fieldsvalidated'] = false
				map_form_results['formvalidationerror'] = 'Error validating form fields.'
			end
			result["formfieldcount"] = form["formfields"].length
			http = Net::HTTP.new(url.host, url.port)
			if form["formurls"][0].include? "https"
				http.use_ssl = true
			end
			request = Net::HTTP::Post.new(url)
			form_submit_data, sample_data = generate_sample_data(form["formid"], form_html)
			result["formfieldsfromdb"] = sample_data
			result["formfields"] = sample_data
			result["samplevalues"] = sample_data
			if form["enable-ajax"] == "true"
				url = URI(site_url + "/wp-admin/admin-ajax.php")
			end
			request["Content-Type"] = 'application/x-www-form-urlencoded'
			if form["enable-ajax"] == "true" or @has_file
				request["Content-Type"] = 'multipart/form-data'
			end
			form_submit_data['form_id'] = "#{form["formid"]}"
			request.set_form_data(form_submit_data)
			response = http.request(request)
			result["formvalidated"] = true	
			response_html = Nokogiri::HTML.parse(response.body)
			success_msg = response_html.css('.forminator-label--forminator-success').text.strip
			if success_msg
				result["formsubmitted"] = true
			else
				result["formvalidationerror"] = "Error in form submission."
			end
			Helper.ss_after_submission(key, form["formurls"], result, screenshots)
			result["formvalidated"] = result["fieldsvalidated"] && result["formsubmitted"] && result["screenshotsvalidated"]
			results << result
		end
		results
	end

	def generate_sample_data(form_id, form_to_test)
		sample_data = []
		form_submit_data = {}
		filename = ''
		fields = form_to_test.css('input') + form_to_test.css('textarea') + form_to_test.css('select')
		fields.each do |field|
			name = field.attr('name')
			type = field.attr('type')
			if type.nil?
				if field.name == 'textarea'
					type = 'textarea'
				elsif field.name == 'select'
					type = 'select'
				end
			end
			value = ''
			case type
			when 'text'
				if name.starts_with?("date")
					date_format = field.attr('data-format')
					now = Time.now
					if date_format == "mm/dd/yy"
						value = now.strftime("%-m/%-d/%Y")
					end
				elsif name.starts_with?("phone")
					value = Faker::Base.numerify('##########')
				else
					value = Faker::Lorem.sentence
				end
			when 'textarea'
				value = Faker::Lorem.sentence
			when 'email'
				value = Faker::Internet.email
			when 'tel'
				value = Faker::Base.numerify('(###) ### ####')
			when 'date'
				value = Faker::Date.between(from: Date.today - 365, to: Date.today)
			when 'number'
				if name.starts_with?("date")
					day_month_year = field.attr('data-field')
					case day_month_year
					when 'day'
						value = Time.now.day.to_s
					when 'month'
						value = Time.now.month.to_s
					when 'year'
						value = Time.now.year.to_s
					end
				elsif field.attr('min')
					value = field.attr('min')
				else
					value = 2485
				end
			when 'checkbox'
				value = field.attr('value')
			when 'radio'
				options = form_to_test.css("input[name=#{name}]")
				value = options[rand(options.length)].attr('value')
			when 'textarea'
				value = Faker::Lorem.paragraph
			when 'range'
				value = field.attr('max')
			when 'select'
				value = field.css('option').last['value']
			when 'file'
				@has_file = true
				url = 'https://sample-videos.com/img/Sample-png-image-100kb.png' 
				filename = 'sample_image.png' 
				File.open(filename, 'wb') do |file|
					file.write open(url).read
				end
				#accepted_exts = field.attr('accept').split(',')
				#filename = "sample#{accepted_exts[0]}"
				file = File.open(filename, "rb")
				value = {
					filename => file.read
				}
				file.close
			when 'hidden'
				value = field.attr('value')	
			end
			if !form_submit_data.key?(name)
				form_submit_data[name] = value
			end
			if type!="hidden"
				label_element = nil
				field = field.ancestors('.forminator-field').first
				label_element =  field.css('*[class="forminator-label"]')
				if !label_element.nil?
					field_name = label_element.xpath('text()').text.strip
					if type=="file"
						sample_data.append({"name" => field_name, "value" => filename, "type" => ""})
					else
						sample_data.append({"name" => field_name, "value" => value, "type" => ""})
					end
				end
			end
			form_submit_data[name] = value
		end
		# "frm_verify" has to be empty for form submission. As it has type
		# "text", it gets assigned a random value.
		form_submit_data["frm_verify"] = form_to_test.css('input[name="frm_verify"]').attr('value').to_s
		return form_submit_data, sample_data
	end
end
