pub type Ticket {
  Ticket(base_url: String, key: String)
}

pub type MergeRequest {
  MergeRequest(base_url: String, project: String, id: String)
}

pub type MergeRequestState(merged_data, opened_data, closed_data) {
  MergeRequestMerged(merged_data)
  MergeRequestOpened(opened_data)
  MergeRequestClosed(closed_data)
}
