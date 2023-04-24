module SearchHelper
	def self.generateUID(formid, formname)
		(formname + "_" + formid.to_s)
	end

	def self.mime_type(filename)
		case File.extname(filename)
		when ".png" then "image/png"
		when ".jpg", ".jpeg" then "image/jpeg"
		when ".gif" then "image/gif"
		else "application/octet-stream"
		end
	end

	def self.ss_after_submission(key, formurls, map_form_results, screenshots)
		map_form_results["formvalidated"] = false
		map_form_results["screenshotsvalidated"] = false
		screenshotsaftersubmission = getscreenshots(key, formurls)
		data, screenshotsvalidated = get_screenshot_data(formurls, screenshots, screenshotsaftersubmission)
		map_form_results['screenshotdataaftersubmission'] = data
		if screenshotsvalidated
			map_form_results["screenshotsvalidated"] = true
		elsif map_form_results["formsubmitted"] == true
			map_form_results["formvalidationerror"] = "Error in screenshot validation."
		end
	end

	def self.post_request(form_url, payload)
		uri = URI.parse(form_url)
		request = Net::HTTP::Post.new(uri)
		request.set_form(payload)
		request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
		http = Net::HTTP.new(uri.host, uri.port)
		if form_url.include? "https"
			http.use_ssl = true
		end
		response = http.request(request)
		response
	end

	def self.validate_form(html_fields, db_fields)
		html_names = []
		db_names = []
		html_fields.each do |field|
			html_names.append(field.gsub(" *", ""))
		end
		db_fields.each do |field|
			name = field.fetch("name", nil)
			type = field.fetch("type", nil)
			if name.present? && type!="submit"
				db_names.append(name)
			end
		end
		missing_fields = db_names - (html_names & db_names)
		return missing_fields.empty?, missing_fields
	rescue
		return false, []
	end

	def self.get_form_html(html_content, formid)
		doc = Nokogiri::HTML(html_content)
		form = doc.css('form').first
		form
	end

	def self.compare_images(image_data1, image_data2)
		data1 = Base64.decode64(image_data1)
		data2 = Base64.decode64(image_data2)
		hash1 = Digest::SHA1.digest(data1)
		hash2 = Digest::SHA1.digest(data2)
		return hash1 == hash2 ? 1.0 : 0.0
	rescue
		return 0.0
	end

	def self.get_screenshot_data(formurls, screenshots, screenshotsaftersubmission)
		data = []
		screenshotsvalidated = true			
		for i in 0...formurls.length do
			img1 = screenshots[i]['screenshot']
			img2 = screenshotsaftersubmission[i]['screenshot']

			if img1.nil? or img2.nil?
				difference = "Failed"
				screenshotsvalidated = false
			else
				score = Helper.compare_images(img1, img2);
				difference = "Yes"
				if score == 1.0
					difference = "No"
				else
					screenshotsvalidated = false
				end
			end
			data << {
				"formurl" => screenshots[i]['formurl'],
				"screenshot_before" => img1,
				"screenshot_after" => img2,
				"difference" => difference }
		end
		return data, screenshotsvalidated
	end

	def self.getscreenshots(key, formurls)
		results = []
		formurls.each do |formurl|
			begin
				uri = URI.parse("http://localhost:3002/search")
				header = {'Content-Type': 'text/json'}
				body = { url: formurl, formId: key }
				http = Net::HTTP.new(uri.host, uri.port)
				request = Net::HTTP::Post.new(uri.request_uri, header)
				request.body = body.to_json
				response = http.request(request)
				result = response.body
				results << { "formurl" => formurl, "screenshot" => result }
			rescue
				results << { "formurl" => formurl, "screenshot" => nil }
			end
		end
		results
	end

	def self.get_form_field_count(sample_values)
		count = 0
		sample_values.each do |sample_value|
			if sample_value["type"] != 'hidden' && sample_value["type"] != 'submit' && sample_value["type"] != 'hr' && sample_value["type"] != 'html' && sample_value["type"] != 'repeater'
				count = count + 1
			end
		end
		count
	end

	def self.get_validations_map(validations)
		arr = validations.split(';')
		map = {}
		arr.each do |item|
			key_value = item.split('=')
			map[key_value[0]] = key_value[1] unless key_value[0].nil?
		end
		map
	end

	def self.generate_sample_values(filename, formfields, formurl, formid, formname)
		sample_values = []
		file_field_present = false
		formfields.each do |field|
			id = field.fetch("id", "")
			name = field.fetch("name", "")
			type = field.fetch("type", "")
			value = field.fetch("value", "")
			validations = field.fetch("validations", "")
			class_attribute = field.fetch("class", "")
			label =  field.fetch("label", "")
			if "WPForms" == formname
				if "name" == type
					if "simple" == validations
						sample_values << {"id" => id, "name" => name, "type" => type, "value" => "sample text", "label" =>"wpforms[fields][#{id}]" }
					else
						name_field = validations
						name_array = name_field.split("-")
						name_array.each do |name|
							sample_values << {"id" => id, "name" => name, "type" => type, "value" => "sample name", "label" => "wpforms[fields][#{id}][#{name}]" }
						end
					end
				else
					file_field_present, sample_value = Helper.get_sample_value(formid, id, name, type, value, validations, formurl, file_field_present, filename, formname)
					sample_values << {"id" => id, "name" => name, "type" => type, "value" => sample_value, "label" => "wpforms[fields][#{id}]" }
				end
			else
				file_field_present, sample_value = Helper.get_sample_value(formid, id, name, type, value, validations, formurl, file_field_present, filename, formname)
				sample_values << {"id" => id, "name" => name, "type" => type, "value" => sample_value, "label" => label }
			end
		end
		return file_field_present, sample_values
	end

	def self.refine_sample_values(temp_sample_values)
		sample_values = []
		temp_sample_values.each do |s_value|
			if !s_value['name'].nil? && !s_value['name'].empty? && s_value['type']!='hr' &&
				s_value['type']!='submit' && s_value['type']!='repeater' &&
				s_value['type']!='html' && s_value['type']!='hidden'
				sample_values << s_value
			end
		end
		sample_values
	end

	def self.get_sample_value(formid, id, name, type, value, validations, formurl, file_field_present, filename, formname)
		validations_map = Helper.get_validations_map(validations)
		samplevalue = value
		case type
		when 'text'
			samplevalue = 'Sample Text'
		when 'email'
			samplevalue = 'sample@email.com'
		when 'number'
			samplevalue = '12345'
		when 'password'
			samplevalue = 'samplepass@123'
		when 'textarea'
			samplevalue = 'Sample Text Area'
		when 'radio'
			samplevalue = "one"
		when "range"
			samplevalue = value
		when 'checkbox'
			samplevalue = "one"
		when 'select'
			samplevalue = "one"
		when 'file'
			if "WPForms" == formname
				samplevalue = WPForms.get_image_data(formid, id, formurl)
			else
				samplevalue = filename
			end
		when 'time'
			samplevalue = "10:10:10"
		when 'date'
			if !validations_map.key?("date_mode")
				samplevalue = "2010-02-21"
			elsif(validations_map['date_mode'] == "time_only")
				if(validations_map['hours_24'] == "0")
					s_value = {
					'date' => '',
					'hour' => '10',
					'minute' => '00',
					'ampm' => 'am'
					}
					samplevalue = s_value
				else
					s_value = {
					'date' => '',
					'hour' => '10',
					'minute' => '00'
					}
					samplevalue = s_value
				end
			else
				date = Helper.get_sample_date(validations_map['date_format'])
				if(validations_map['date_mode'] == "date_only")
					samplevalue = date
				else
					if(validations_map['hours_24'] == "0")
						s_value = {
						'date' => date,
						'hour' => '10',
						'minute' => '00',
						'ampm' => 'am'
						}
						samplevalue = s_value
					else
						s_value = {
						'date' => date,
						'hour' => '10',
						'minute' => '00'
						}
						samplevalue = s_value
					end
				end
			end
		when 'tel'
			samplevalue = '+11234567890'
		when 'phone'
			samplevalue = '+11234567890'
		when 'url'
			samplevalue = 'https://www.example.com'
		when 'color'
			samplevalue = '#000000'
		when 'hidden'
			samplevalue = value
		when 'hr'
			samplevalue = value
		when 'submit'
			samplevalue = value
		when 'firstname'
			samplevalue = 'Sample First Name'
		when 'lastname'
			samplevalue = 'Sample Last Name'
		when 'textbox'
			samplevalue = 'Sample Text'
		when 'listcheckbox'
			s_value = []
			s_value << "one"
			s_value << "two"
			samplevalue = s_value
		when 'listimage'
		when 'listmultiselect'
			s_value = []
			s_value << "one"
			s_value << "two"
			samplevalue = s_value
		when 'listradio'
			samplevalue = "one"
		when 'listselect'
			samplevalue = "one"
		when 'address'
			samplevalue = 'Sample Address'
		when 'zip'
			samplevalue = '000000'
		when 'liststate'
			samplevalue = 'Alaska'
		when 'listcountry'
			samplevalue = 'US'
		when 'confirm'
			samplevalue = 'Confirm'
		when 'spam'
			samplevalue = value
		when 'starrating'
			samplevalue = "2"
		else
			samplevalue = 'Sample Value'
		end
		if validations_map['minvalue']
			samplevalue = (validations_map['minvalue'].to_i + 1).to_s
		end
		if validations_map['maxvalue']
			samplevalue = (validations_map['maxvalue'].to_i - 1).to_s
		end
		if validations_map['minlength']
			minlength = validations_map['minlength']
			if samplevalue.length < minlength.to_i
				samplevalue = samplevalue.rjust(minlength.to_i, '0')
			end
		end
		if validations_map['maxlength']
			maxlength = validations_map['maxlength']
			if samplevalue.length > maxlength.to_i
				samplevalue = samplevalue[0, maxlength.to_i]
			end
		end
		return file_field_present, samplevalue
	end

	def self.get_sample_date(date_format)
		case date_format
		when "DD/MM/YYYY"
		'17/03/2023'
		when 'DD-MM-YYYY'
		'17-03-2023'
		when 'DD.MM.YYYY'
		'17.03.2023'
		when 'MM/DD/YYYY'
		'03/17/2023'
		when 'MM-DD-YYYY'
		'03-17-2023'
		when 'MM.DD.YYYY'
		'03.17.2023'
		when 'YYYY-MM-DD'
		'2023-03-17'
		when 'YYY/MM/DD'
		'2023/03/17'
		when 'YYYY.MM.DD'
		'2023.03.17'
		when "dddd, MMMM D YYYY"
		'Friday, November 18, 2019'
		else
			'2023-01-30'
		end
	end
end
