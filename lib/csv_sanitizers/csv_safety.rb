module CsvSanitizers
  module CsvSafety
    DANGEROUS_PREFIXES = %w[= + - @].freeze

    def self.sanitize_cell(value)
      stringified = value.to_s
      return stringified unless DANGEROUS_PREFIXES.any? { |prefix| stringified.start_with?(prefix) }

      "'#{stringified}"
    end
  end
end
