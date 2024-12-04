class ThreadsController < ApplicationController
  def index
    @threads_container = EmailThreadsContainer.new(current_user)
    @threads_container.load_threads
  end

  def show
    @threads_container = EmailThreadsContainer.new(current_user)
    @thread = @threads_container.get_thread(params[:id])
  end
end