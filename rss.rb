require 'pry-byebug'

require 'graphql/client'
require 'graphql/client/http'
require 'rss'

BASE_URL = 'https://republik.ch'

http_client = GraphQL::Client::HTTP.new('https://api.republik.ch/graphql') do
  def headers(context)
    # Optionally set any HTTP headers
    { 
      'Cookie': ENV['cookie']
    }
  end
end

schema = GraphQL::Client.load_schema('schema.json')
graphql_client = GraphQL::Client.new(schema: schema, execute: http_client)

GET_SEARCH_RESULTS_QUERY = graphql_client.parse <<-'GRAPHQL'
query($search: String, $after: String, $sort: SearchSortInput, $filters: [SearchGenericFilterInput!], $trackingId: ID) {
  search(first: 100, after: $after, search: $search, sort: $sort, filters: $filters, trackingId: $trackingId) {
    totalCount
    trackingId
    nodes {
      entity {
        __typename
        ... on Document {
          ...DocumentListDocument
          __typename
        }
        ... on Comment {
          id
          content
          text
          preview(length: 240) {
            string
            more
            __typename
          }
          createdAt
          displayAuthor {
            id
            name
            username
            profilePicture
            credential {
              description
              verified
              __typename
            }
            __typename
          }
          published
          updatedAt
          tags
          parentIds
          discussion {
            id
            title
            path
            document {
              id
              meta {
                title
                path
                template
                ownDiscussion {
                  id
                  closed
                  __typename
                }
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
        ... on User {
          id
          username
          firstName
          lastName
          credentials {
            verified
            description
            isListed
            __typename
          }
          portrait
          hasPublicProfile
          __typename
        }
      }
      highlights {
        path
        fragments
        __typename
      }
      score
      __typename
    }
    __typename
  }
}
fragment DocumentListDocument on Document {
  id
  meta {
    credits
    title
    description
    publishDate
    prepublication
    path
    kind
    template
    color
    estimatedReadingMinutes
    estimatedConsumptionMinutes
    indicateChart
    indicateGallery
    indicateVideo
    audioSource {
      mp3
      __typename
    }
    dossier {
      id
      __typename
    }
    format {
      meta {
        path
        title
        color
        kind
        __typename
      }
      __typename
    }
    ownDiscussion {
      id
      closed
      comments {
        totalCount
        __typename
      }
      __typename
    }
    linkedDiscussion {
      id
      path
      closed
      comments {
        totalCount
        __typename
      }
      __typename
    }
    __typename
  }
  __typename
}
GRAPHQL

result = graphql_client.query(GET_SEARCH_RESULTS_QUERY, variables: {search: '', sort: {key: 'publishedAt'}, filters: [{key: 'audioSource', value: 'true'}]})

feed = RSS::Maker.make('2.0') do |maker|
  maker.channel.author = 'https://republik.ch'
  maker.channel.updated = Time.now.to_s
  maker.channel.about = 'feed.rss'
  maker.channel.title = 'Republik: Vorgelesene Artikel'
  maker.channel.link = 'https://republik.ch'
  maker.channel.description = 'Republik: Vorgelesene Artikel'

  result.data.search.nodes.each do |node|
    maker.items.new_item do |item|
      url = "#{BASE_URL}#{node.entity.meta.path}"

      item.id = Base64.decode64(node.entity.id)
      item.link = url
      item.title = node.entity.meta.title
      item.updated = node.entity.meta.publish_date

      item.enclosure.type = 'audio/mpeg'
      item.enclosure.url = node.entity.meta.audio_source.mp3
      item.enclosure.length = 1

      item.description = node.entity.meta.description
    end
  end
end

puts feed.to_s
