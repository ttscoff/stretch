# app.rb
require 'sinatra'
require 'httparty'
require 'uri'
require 'json'

# Function to clean tracking parameters from the URL
def clean_url(url)
  uri = URI.parse(url)

  return url unless uri.query

  # Define parameters to clean
  unwanted_params = %w[
    utm
    tracking
    source
    tag
    ascsub
    sub
    linkCode
    ref
    ir
    clickid
    sharedid
    mpaid
  ]

  # Clean the query from the unwanted parameters
  uri.query = URI.decode_www_form(uri.query).reject { |param| unwanted_params.any? { |unwanted| param[0].start_with?(unwanted) } }.map { |param| param.join('=') }.join('&')

  # Update the URI with the cleaned query
  uri.query = uri.query.empty? ? nil : uri.query
  uri.to_s
end

def query(url)
  uri = URI.parse(url)
  uri.query
end

# Function to shorten Amazon URLs to the necessary components
def shorten_amazon(url, clean: true)
  uri = URI.parse(url)

  # Return nil if not an Amazon URL
  return nil unless uri.host.include?('amazon')

  # Extract the product ID from the path
  match = uri.path.match(/\/dp\/([^\/]*)/)
  product_id = match ? match[1] : nil

  # Construct the shortened URL if the product ID is found
  clean_url = product_id ? "https://www.amazon.com/dp/#{product_id}" : nil

  # Return the shortened URL
  if clean
    clean_url
  else
    clean_url + uri.query.to_s
  end
end

# Route to expand shortened URLs
get '/expand' do
  content_type :json

  # Get the "url" and "clean" query parameters
  original_url = params['url']
  clean_param = params['clean']
  shorten_amazon = params['tidy_amazon']

  return { error: 'URL parameter is required' }.to_json if original_url.nil? || original_url.strip.empty?

  # Use HTTParty to perform a HEAD request to follow redirects
  begin
    response = HTTParty.head(original_url, follow_redirects: false)
    final_url = response.headers['location'] || original_url

    # Clean the URL only if the 'clean' parameter is present and truthy
    cleaned_url = (clean_param =~ /^[t1]/) ? clean_url(final_url) : final_url
    cleaned_url = (shorten_amazon == 'true' || shorten_amazon == '1') ? shorten_amazon(cleaned_url, clean: clean_param !~ /^[f0]/) : cleaned_url

    { original_url: original_url, expanded_url: cleaned_url }.to_json
  rescue => e
    { error: e.message }.to_json
  end
end

# Route to shorten Amazon URLs
get '/shorten_amazon' do
  content_type :json

  # Get the "url" query parameter
  original_url = params['url']
  clean = params['clean']
  return { error: 'URL parameter is required' }.to_json if original_url.nil? || original_url.strip.empty?

  # Shorten the provided Amazon URL
  shortened_url = shorten_amazon(original_url, clean: clean !~ /^[f0]/)

  # Return the shortened URL or an error if it couldn't be shortened
  if shortened_url
    { original_url: original_url, shortened_url: shortened_url }.to_json
  else
    { error: 'Provided URL is not a valid Amazon URL' }.to_json
  end
end

# Route to clean tracking parameters from URLs
get '/clean' do
  content_type :json

  # Get the "url" query parameter
  original_url = params['url']
  return { error: 'URL parameter is required' }.to_json if original_url.nil? || original_url.strip.empty?

  begin
    # Shorten the provided Amazon URL
    cleaned_url = clean_url(original_url)

    # Return the shortened URL or an error if it couldn't be shortened
    { original_url: original_url, cleaned_url: cleaned_url }.to_json
  rescue => e
    { error: e.message }.to_json
  end
end
