class TimeEntriesController < ApplicationController
  before_action :set_entry, only: [:edit, :update, :destroy, :clock_out, :clock_out_update, :switch_task, :switch_task_update, :admin_approve, :admin_reject]

  def index
    current_user.has_roles?(:admin) ? @entries = TimeEntry.order(start_time: :desc) : @entries = TimeEntry.where(user_id: current_user.id).order(start_time: :desc)
    @current_entry = TimeEntry.where(user_id: current_user.id, end_time: nil).last
    @pending = TimeEntry.where(status: 'pending')
    @todays_entries = TimeEntry.todays_entries @entries
    @weeks_entries = TimeEntry.this_weeks_entries(@entries)
    @rejected = TimeEntry.where(user_id: current_user.id, status: 'rejected')
  end

  def new
    @entry = TimeEntry.new
  end

  def create
    @entry = TimeEntry.new(time_entry_params)
    @entry.user_id = current_user.id
    if @entry.save
      redirect_to time_entries_path
    else
      redirect_to new_time_entry_path
    end
  end

  def edit

  end

  def update
    if @entry.update(time_entry_params)
      @entry.save

      #get all the task for this employee this week
      ws = @entry.task_entries.last.find_start_of_week
      we = @entry.task_entries.last.find_end_of_week

      tasks = get_task_between(ws, we)

      t_hours = 0
      t_ot = 0

      tasks.each do |task|
        task.hours_generator
        if t_ot > 0
          task.is_overtime
          t_ot += task.overtime
        elsif t_hours + task.hours > 4000
          task.overtime_generator t_hours
          t_hours += task.hours
          t_ot += task.overtime
        else
          task.no_overtime
          t_hours += task.hours
        end

      end

      @entry.pending!
      redirect_to time_entries_path, notice: 'Your time entry edit was submitted for approval'
    else
      render :edit, notice: 'Error submitting your request'
    end
  end

  def destroy
    if @entry.destroy
      redirect_to time_entries_path, notice: 'Your time entry has been deleted'
    else
      render :index, notice: 'Your time entry could not be deleted'
    end
  end

  def clock_out
    @current_entry = TimeEntry.where(user_id: current_user.id).last
  end

  def clock_out_update
    if @entry.update(time_entry_params)
      @entry.save
      @entry.approved!

      @entry.task_entries.last.hours_generator
      tasks = get_task_between(TimeEntry.find_start_of_week, @entry.task_entries.last.start_date - 1)
      t_hours = tasks.map(&:hours).map(&:to_f).sum
      t_ot = tasks.map(&:overtime).map(&:to_f).sum
      
      if t_ot > 0
        @entry.task_entries.last.is_overtime
      elsif t_hours + @entry.task_entries.last.hours <= 4000
        @entry.task_entries.last.no_overtime
      else
        @entry.task_entries.last.overtime_generator t_hours
      end

      redirect_to time_entries_path, notice: 'Clocked Out'
    else
      render :edit, notice: 'Error submitting your request'
    end
  end

  def switch_task
  end

  def switch_task_update
    if @entry.update(time_entry_params)
      
      @entry.save
      @entry.task_entries.last(2)[0].hours_generator
      tasks = get_task_between(TimeEntry.find_start_of_week, @entry.task_entries.last(2)[0].start_date - 1)
      t_hours = tasks.map(&:hours).sum
      t_ot = tasks.map(&:overtime).sum
  
      if t_ot > 0
        @entry.task_entries.last(2)[0].is_overtime
      elsif t_hours + @entry.task_entries.last(2)[0].hours <= 4000   
        @entry.task_entries.last(2)[0].no_overtime
      else        
        @entry.task_entries.last(2)[0].overtime_generator t_hours
      end

      redirect_to time_entries_path, notice: 'Task Switched'
    else
      redirect_to :switch_task
    end
  end

  def admin_approve
    @entry.approved!
    redirect_to :root
  end

  def admin_reject
    @entry.rejected!
    redirect_to :root
  end

  private

  def set_entry
    @entry = TimeEntry.find(params[:id])
  end

  def time_entry_params
    params.require(:time_entry).permit( 
      :start_date, 
      :start_time, 
      :end_date, 
      :end_time, 
      :user_id, 
      :task_entry,
      task_entries_attributes:
      [ :id,
        :start_date,
        :start_time,
        :end_date,
        :end_time,
        :task_id,
        :job_id,
        :_destroy])
  end


  def get_task_between(strt, en)
    tasks = TaskEntry.order("start_date ASC, start_time ASC")
    tasks = tasks.select { |e| e.time_entry.user_id == @entry.user_id}
    tasks = tasks.select { |e| e.start_date.between?(strt, en) == true }
  end
end
