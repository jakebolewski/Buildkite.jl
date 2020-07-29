__precompile__(false)

module Buildkite

import HTTP
import JSON

export BuildkiteAPI

abstract type AbstractBuildkiteAPI end

Base.@kwdef struct BuildkiteAPI <: AbstractBuildkiteAPI
    base_url::HTTP.URI = HTTP.URI("https://api.buildkite.com/v2/")
    access_token::String = ""
end

function buildkite_api_uri(api::BuildkiteAPI, path)
    HTTP.URIs.merge(api.base_url, path = api.base_url.path * path) 
end

function buildkite_request(api::BuildkiteAPI, request_method, endpoint; 
                           handle_error = true,
                           headers = Dict(), 
                           params = Dict(), 
                           allowredirects::Bool = true,
                           idle_timeout = 20,
                           status_exception = false)
    api_endpoint = buildkite_api_uri(api, endpoint)
    request_headers = convert(Dict{String, String}, headers)
    if !haskey(request_headers, "Authorization")
        request_headers["Authorization"] = "Bearer $(api.access_token)"
    end
    if !haskey(request_headers, "User-Agent")
        request_headers["User-Agent"] = "Buildkite-jl"
    end
    if request_method == HTTP.get
        api_uri = HTTP.URIs.merge(api_endpoint, query = params)
        println("DEBUG: ", api_uri)
        r = request_method(api_uri, request_headers, 
                           redirect = allowredirects, status_exception = false, idle_timeout=idle_timeout)
    else
        api_uri = string(api_uri)
        r = request_method(api_uri, request_headers, JSON.json(params), 
                           redirect=allowredirects, 
                           status_exception=status_exception, 
                           idle_timeout=idle_timeout)
    end
    if handle_error
        #handle_response_error(r)
    end
    return r
end

# REST primitives

function buildkite_get(api::BuildkiteAPI, endpoint = ""; options...)
    buildkite_request(api, HTTP.get, endpoint; options...)
end

function buildkite_post(api::BuildkiteAPI, endpoint = ""; options...)
    buildkite_request(api, HTTP.post, endpoint; options...)
end

function buildkite_put(api::BuildkiteAPI, endpoint = ""; options...)
    buildkite_request(api, HTTP.put, endpoint; options...)
end

function buildkite_delete(api::BuildkiteAPI, endpoint = ""; options...)
    buildkite_request(api, HTTP.delete, endpoint; options...)
end

function buildkite_patch(api::BuildkiteAPI, endpoint = ""; options...)
    buildkite_request(api, HTTP.patch, endpoint; options...)
end

function buildkite_get_json(api::BuildkiteAPI, endpoint = ""; options...) 
    JSON.parse(HTTP.payload(buildkite_get(api, endpoint; options...), String))
end

function buildkite_post_json(api::BuildkiteAPI, endpoint = ""; options...)
    JSON.parse(HTTP.payload(buildkite_post(api, endpoint; options...), String))
end

function buildkite_put_json(api::BuildkiteAPI, endpoint = ""; options...)
    JSON.parse(HTTP.payload(buildkite_put(api, endpoint; options...), String))
end

function buildkite_delete_json(api::BuildkiteAPI, endpoint = ""; options...)
    JSON.parse(HTTP.payload(buildkite_delete(api, endpoint; options...), String))
end

function buildkite_patch_json(api::BuildkiteAPI, endpoint = ""; options...)
    JSON.parse(HTTP.payload(buildkite_patch(api, endpoint; options...), String))
end

function hello_world()
    base_url = HTTP.URI("https://api.buildkite.com")
    r = buildkite_get_json(BuildkiteAPI(base_url=base_url), "")
    return r["response"]
end

# organization api

struct Organization
    api::BuildkiteAPI
    data::Dict
end

function organization(api::BuildkiteAPI, name)
    return Organization(api, buildkite_get_json(api, "organizations/$(lowercase(name))"))
end

# pipelines api

struct Pipeline
    api::BuildkiteAPI
    data::Dict
end

function pipelines(api::BuildkiteAPI, organization; page=0, pagination=false)
    query_params = Dict("page" => page)
    endpoint = "organizations/$(lowercase(organization))/pipelines"
    return [Pipeline(api, p) for p in buildkite_get_json(api, endpoint; params = query_params)]
end

function pipelines(org::Buildkite.Organization)
    return pipelines(org.api, org.data["name"])
end

# build api

struct Build
    api::BuildkiteAPI
    data::Dict
end

function builds(api::BuildkiteAPI; state=nothing)
    query_params = Dict("state" => state)
    endpoint = "builds"
    return [Build(api, b) for b in buildkite_get_json(api, endpoint; params = query_params)]
end

build_state(b::Build) = b.data["state"]

end
