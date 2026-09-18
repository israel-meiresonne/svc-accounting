module JsonWebTokens::Configurable
  private

  def config
    @config ||= JsonWebTokens::Configurations::Base.run
  end
end
