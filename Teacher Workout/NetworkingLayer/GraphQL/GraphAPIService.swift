import Apollo
import Foundation

class GraphAPIService: DataProviderProtocol {
    private(set) lazy var apolloClient: ApolloClient = {
        let configuration = URLSessionConfiguration.default

        let client = URLSessionClient(sessionConfiguration: configuration)

        let url = URL(string: NetworkingConstants.baseURL)!
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)

        let provider = NetworkInterceptorProvider(client: client, store: store)
        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: url)

        let apolloClient = ApolloClient(networkTransport: transport, store: store)
        return apolloClient
    }()

    func getThemes(completion: @escaping (Result<[Theme], Error>) -> Void) {
        let query = ThemesQuery()
        apolloClient.fetch(query: query) { result in
            switch result {
            case let .failure(error):
                let queryResult = Result<[Theme], Error>.failure(error)
                completion(queryResult)
            case let .success(value):
                guard let themesResponse = value.data?.themes?.edges else {
                    let queryResult = Result<[Theme], Error>.failure(APIError.invalidContent)
                    completion(queryResult)
                    return
                }

                let themesQueryResponse = themesResponse.compactMap { edge in
                    Theme(themeNode: edge?.node)
                }

                let queryResult = Result<[Theme], Error>.success(themesQueryResponse)
                completion(queryResult)
            }
        }
    }
}

class NetworkInterceptorProvider: DefaultInterceptorProvider {
    override func interceptors<Operation>(for operation: Operation) -> [ApolloInterceptor] where Operation: GraphQLOperation {
        var interceptors = super.interceptors(for: operation)
        interceptors.insert(NetworkInterceptor(), at: 0)
        return interceptors
    }
}

class NetworkInterceptor: ApolloInterceptor {
    func interceptAsync<Operation>(chain: RequestChain,
                                   request: HTTPRequest<Operation>,
                                   response: HTTPResponse<Operation>?,
                                   completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void) where Operation: GraphQLOperation
    {
        chain.proceedAsync(request: request,
                           response: response,
                           completion: completion)
    }
}
