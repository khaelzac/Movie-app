const IMAGE_BASE_URL = 'https://image.tmdb.org/t/p';

const imageUrl = (path, size) => {
  if (!path) return null;
  return `${IMAGE_BASE_URL}/${size}${path}`;
};

const mediaTypeFrom = (item, fallback = 'movie') => {
  if (item.media_type === 'movie' || item.media_type === 'tv') return item.media_type;
  if (item.title || item.release_date) return 'movie';
  if (item.name || item.first_air_date) return 'tv';
  return fallback;
};

const formatMediaItem = (item, fallbackMediaType = 'movie') => ({
  id: item.id,
  mediaType: mediaTypeFrom(item, fallbackMediaType),
  title: item.title || item.name || 'Untitled',
  overview: item.overview || '',
  posterPath: item.poster_path || null,
  backdropPath: item.backdrop_path || null,
  posterUrl: imageUrl(item.poster_path, 'w500'),
  backdropUrl: imageUrl(item.backdrop_path, 'w1280'),
  releaseDate: item.release_date || item.first_air_date || null,
  voteAverage: item.vote_average || 0,
  voteCount: item.vote_count || 0,
  popularity: item.popularity || 0
});

const formatCastMember = (person) => ({
  id: person.id,
  name: person.name || 'Unknown',
  character: person.character || '',
  profilePath: person.profile_path || null,
  profileUrl: imageUrl(person.profile_path, 'w185')
});

const formatList = (payload, fallbackMediaType = 'movie') => ({
  page: payload.page || 1,
  totalPages: payload.total_pages || 0,
  totalResults: payload.total_results || 0,
  results: (payload.results || [])
    .filter((item) => item.media_type !== 'person')
    .map((item) => formatMediaItem(item, fallbackMediaType))
});

const formatDetails = (payload, mediaType) => ({
  id: payload.id,
  mediaType,
  title: payload.title || payload.name || 'Untitled',
  overview: payload.overview || '',
  tagline: payload.tagline || '',
  posterPath: payload.poster_path || null,
  backdropPath: payload.backdrop_path || null,
  posterUrl: imageUrl(payload.poster_path, 'w500'),
  backdropUrl: imageUrl(payload.backdrop_path, 'w1280'),
  releaseDate: payload.release_date || payload.first_air_date || null,
  runtime: payload.runtime || null,
  episodeRunTime: payload.episode_run_time || [],
  numberOfSeasons: payload.number_of_seasons || null,
  numberOfEpisodes: payload.number_of_episodes || null,
  genres: payload.genres || [],
  voteAverage: payload.vote_average || 0,
  voteCount: payload.vote_count || 0,
  status: payload.status || null,
  cast: (payload.credits?.cast || []).slice(0, 18).map(formatCastMember),
  recommendations: payload.recommendations ? formatList(payload.recommendations, mediaType).results : [],
  similar: payload.similar ? formatList(payload.similar, mediaType).results : []
});

const formatGenres = (payload) => ({
  genres: payload.genres || []
});

const formatSeason = (payload) => ({
  id: payload.id,
  name: payload.name || '',
  seasonNumber: payload.season_number || 0,
  episodeCount: (payload.episodes || []).length,
  episodes: (payload.episodes || []).map((episode) => ({
    id: episode.id,
    name: episode.name || `Episode ${episode.episode_number}`,
    overview: episode.overview || '',
    episodeNumber: episode.episode_number,
    seasonNumber: episode.season_number,
    airDate: episode.air_date || null,
    stillUrl: imageUrl(episode.still_path, 'w300'),
    voteAverage: episode.vote_average || 0,
    runtime: episode.runtime || null
  }))
});

module.exports = {
  formatDetails,
  formatGenres,
  formatList,
  formatSeason,
  formatMediaItem
};
