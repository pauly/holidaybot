#!/usr/bin/ruby

# A twitter bot, in ruby. Not done one of these for a while!
# Usage: source config/default.sh && ruby holidaybot.sh

require 'rubygems'
require 'twitter'
require 'addressable/uri'
require 'faraday'
require 'json'
require 'pp'
   
class Holidaybot

  def airports
    airports = {}
    response = Faraday.get 'http://api.holidayextras.co.uk/location.js?key=holidaybot&type=1'
    airports_json = JSON.parse response.body
    airports_json['API_Reply']['Product'].each do |airport|
      airports[airport['Name']] = airport['Code']
    end
    airports
  end

  def replied_to
    replied_to = {}
    Twitter.user_timeline.each do |tweet|
      if tweet[:attrs][:in_reply_to_status_id]
        replied_to[ tweet[:attrs][:in_reply_to_status_id].to_s ] = true
      end
    end
    pp replied_to
    replied_to
  end

  def get_date_from a
    if a
      day = '%02d' % a[0].to_f
      month = '%02d' % a[1].to_f
      return '2012-' + month + '-' + day + ' 06:00'
    end
  end

  def update update, options
    pp options
    begin
      Twitter.update update, options
    rescue Exception => e
      pp e
    end
  end

  def get_airport_from tweet
    location = 'LGW'
    self.airports.each do |name,code|
      if tweet[:text].upcase.match name.upcase
        param[:location] = code
      end
    end
    # if no airport get the nearest one to that location?
    location
  end

  def get_carpark param
    uri = Addressable::URI.new
    uri.query_values = param
    url = 'http://hapi.holidayextras.co.uk/carparks?' + uri.query
    response = Faraday.get url
    if response.success?
      carparks = JSON.parse response.body
      carparks[0]
    end
  end

  def go
    mentions = Twitter.mentions_timeline
    replied_to = self.replied_to
    puts mentions.length.to_s + ' mentions'
    mentions.each do |tweet|
      if ! replied_to[ tweet[:attrs][:id_str] ]
        param = { :agent => 'WEB1', :token => 'f135530a-c5e5-4fff-a096-f317ad783b22', :product => 'cp' }
    
        param[:location] = self.get_airport_from tweet
        matches = tweet[:text].scan( /(\d+)\/(\d+)(\/(\d+))?/ )
        param[:from] = self.get_date_from matches[0]
        param[:to] = self.get_date_from matches[1]
        if ! param[:from]
          matches = tweet[:text].scan( /(october) (\d+)( (\d+:\d+))?/i )
          if matches[0]
            pp matches
            param[:from] = '2012-10-' + ( '%02d' % matches[0][1].to_f ) + ' ' + matches[0][3]
          end
        end
        site = 'http://app.holidayextras.co.uk'
        update = '@' + tweet[:attrs][:user][:screen_name] + ' '
        options = { :in_reply_to_status_id => tweet[:attrs][:id_str] }
        if param[:location] and param[:to] and param[:from]
          carpark = self.get_carpark param
          if carpark
            price = carpark['price'] / 100;
            param[:product] = 'cp'
            param[:request] = 1
            uri.query_values = param
            update += carpark['name'] + ' £' + price.to_s + ' ' + site + '/availability?' + uri.query + ' #holidayextras'
            options[:lat] = carpark['lat']
            options[:long] = carpark['lon']
            self.update update, options
          else
            # update = carparks[:message] + ' - try ' + site
            pp carparks
          end
        else
          puts 'missing param; ' + tweet[:text] + ' (' + tweet[:attrs][:user][:screen_name] + ') got ' + param.inspect
          self.update update + ' try gatwick parking 10/10 to 18/10 or go to ' + site, options
        end
      end
    end
  end
end

Holidaybot.new.go
